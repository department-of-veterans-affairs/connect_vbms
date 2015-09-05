module VBMS
  # rubocop:disable Metrics/ClassLength
  class Client
    attr_reader :endpoint_url
    
    def self.from_env_vars(logger: nil, env_name: 'test')
      env_dir = File.join(get_env('CONNECT_VBMS_ENV_DIR'), env_name)
      VBMS::Client.new(
        get_env('CONNECT_VBMS_URL'),
        env_path(env_dir, 'CONNECT_VBMS_KEYFILE'),
        env_path(env_dir, 'CONNECT_VBMS_SAML'),
        env_path(env_dir, 'CONNECT_VBMS_KEY', allow_empty: true),
        get_env('CONNECT_VBMS_KEYPASS'),
        env_path(env_dir, 'CONNECT_VBMS_CACERT', allow_empty: true),
        env_path(env_dir, 'CONNECT_VBMS_CERT', allow_empty: true),
        logger
      )
    end

    def self.get_env(env_var_name, allow_empty: false)
      value = ENV[env_var_name]
      if !allow_empty && (value.nil? || value.empty?)
        fail EnvironmentError, "#{env_var_name} must be set"
      end
      value
    end

    def self.env_path(env_dir, env_var_name, allow_empty: false)
      value = get_env(env_var_name, allow_empty: allow_empty)
      if value.nil?
        return nil
      else
        return File.join(env_dir, value)
      end
    end

    def initialize(endpoint_url, keyfile, saml, key, keypass, cacert,
                   client_cert, logger = nil)
      @endpoint_url = endpoint_url
      @keyfile = keyfile
      @saml = saml
      @key = key
      @keypass = keypass
      @cacert = cacert
      @client_cert = client_cert

      @logger = logger
    end

    def log(event, data)
      @logger.log(event, data) if @logger
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def send(request)
      unencrypted_xml = request.render_xml

      log(
        :unencrypted_xml,
        unencrypted_body: unencrypted_xml
      )

      output = VBMS.encrypted_soap_document_xml(
        unencrypted_xml,
        @keyfile,
        @keypass,
        request.name)
      doc = Nokogiri::XML(output)
      inject_saml(doc)
      remove_must_understand(doc)

      body = create_body(request, doc)

      http_request = build_request(
        body,
        'Content-Type' => 'Multipart/Related; '\
                  'type="application/xop+xml"; '\
                  'start-info="application/soap+xml"; '\
                  'boundary="boundary_1234"')
      HTTPI.log = false
      response = HTTPI.post(http_request)

      log(
        :request,
        response_code: response.code,
        request_body: doc.to_s,
        response_body: response.body,
        request: request
      )

      if response.code != 200
        fail VBMS::HTTPError.new(response.code, response.body)
      end

      process_response(request, response)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def inject_saml(doc)
      saml_doc = Nokogiri::XML(File.read(@saml)).root
      doc.at_xpath(
        '//wsse:Security',
        wsse: 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
      ) << saml_doc
    end

    def remove_must_understand(doc)
      doc.at_xpath(
        '//wsse:Security',
        wsse: 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
      ).attributes['mustUnderstand'].remove
    end

    def create_body(request, doc)
      if request.multipart?
        filepath = request.multipart_file
        filename = File.basename(filepath)
        content = File.read(filepath)
        return VBMS.load_erb('mtom_request.erb').result(binding)
      else
        return VBMS.load_erb('request.erb').result(binding)
      end
    end

    # rubocop:disable Metrics/AbcSize
    def build_request(body, headers)
      request = HTTPI::Request.new(@endpoint_url)
      if @key
        request.auth.ssl.cert_key_file = @key
        request.auth.ssl.cert_key_password = @keypass
        request.auth.ssl.cert_file = @client_cert
        request.auth.ssl.ca_cert_file = @cacert
        request.auth.ssl.verify_mode = :peer
      else
        # TODO: this can't really be correct
        request.auth.ssl.verify_mode = :none
      end

      request.body = body
      request.headers = headers
      request
    end
    # rubocop:enable Metrics/AbcSize

    def parse_xml_strictly(xml_string)
      Nokogiri::XML(xml_string, nil, nil, Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET)
    end

    def get_body(response_body)
      message = Mail.read_from_string(response_body)
      if message.multipart?
        message.body.parts[0].body.to_s
      else
        response_body
      end
    end

    # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    def process_response(request, response)
      body = get_body(response.body)

      # we could check the response content-type to make sure it's XML, but they don't seem
      # to send any HTTP headers back, so we'll instead rely on strict XML parsing instead
      begin
        full_doc = parse_xml_strictly(body)
      rescue Nokogiri::XML::SyntaxError
        raise SOAPError.new("Unable to parse SOAP response", response.body)
      end

      # the envelope should be the root node of the document
      soap = full_doc.at_xpath("/soapenv:Envelope", VBMS::XML_NAMESPACES)
      if soap.nil?
        fail SOAPError.new("No SOAP envelope found in response", response.body)
      end

      if soap.at_xpath('//soapenv:Fault', VBMS::XML_NAMESPACES)
        fail SOAPError.new("SOAP Fault returned", response.body)
      end

      data = nil

      begin
        Tempfile.open('log') do |out_t|
          data = VBMS.decrypt_message_xml(body, @keyfile, @keypass, out_t.path)
        end
      rescue ExecutionError
        raise SOAPError.new("Unable to decrypt SOAP response", response.body)
      end

      log(:decrypted_message, decrypted_data: data, request: request)

      begin
        doc = parse_xml_strictly(data)
      rescue Nokogiri::XML::SyntaxError
        raise SOAPError.new("Unable to parse decrypted SOAP response", data)
      end

      request.handle_response(doc)
    end
    # rubocop:enable Metrics/MethodLength,Metrics/AbcSize
  end
  # rubocop:enable Metrics/ClassLength
end
