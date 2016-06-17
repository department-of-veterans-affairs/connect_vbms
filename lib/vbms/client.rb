module VBMS
  # rubocop:disable Metrics/ClassLength
  class Client
    attr_reader :endpoint_url

    def initialize(endpoint_url, keyfile, saml, key, keypass, cacert,
                   client_cert, server_keyfile, logger = nil)
      @endpoint_url = endpoint_url
      @keyfile = keyfile
      @saml = saml
      @key = key
      @keypass = keypass
      @cacert = cacert
      @client_cert = client_cert
      @server_key = server_keyfile

      # TODO: remove @keystore and improve access via processor
      @keystore = SoapScum::KeyStore.new

      @keystore.add_pc12(@keyfile, @keypass) if @keyfile
      @keystore.add_cert(@server_key) if @server_key && @server_key.match(/.crt/)

      @processor = SoapScum::MessageProcessor.new(@keystore)

      @logger = logger
    end

    def self.from_env_vars(logger: nil, env_name: 'test', lang: 'ruby')
      env_dir = File.join(get_env('CONNECT_VBMS_ENV_DIR'), env_name)

      VBMS::Client.new(
        get_env('CONNECT_VBMS_URL'),
        env_path(env_dir, 'CONNECT_VBMS_CLIENT_KEY_FILE'),
        env_path(env_dir, 'CONNECT_VBMS_SAML'),
        env_path(env_dir, 'CONNECT_VBMS_IMPORT_KEY_FILE', allow_empty: true),
        get_env('CONNECT_VBMS_KEYPASS'),
        env_path(env_dir, 'CONNECT_VBMS_CACERT', allow_empty: true),
        env_path(env_dir, 'CONNECT_VBMS_CERT', allow_empty: true),
        env_path(env_dir, 'CONNECT_VBMS_SERVER_KEY_FILE', allow_empty: true),
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
      return nil if value.nil?

      File.join(env_dir, value)
    end

    def log(event, data)
      @logger.log(event, data) if @logger
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def send_request(request)
      encrypted_doc = @processor.encrypt(request.soap_doc,
                                         request.name,
                                         crypto_options,
                                         request.signed_elements)


      inject_saml(encrypted_doc)
      remove_must_understand(encrypted_doc)
      serialized_doc = serialize_document(encrypted_doc)
      body = create_body(request, serialized_doc)

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
        request_body: serialized_doc.to_s,
        response_body: response.body,
        request: request
      )

      if response.code != 200
        fail VBMS::HTTPError.new(response.code, response.body)
      end

      process_response(request, response)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def send(request)
      # the Gem::Deprecate method didn't work because this method was named send
      msg = "NOTE: Client#send is deprecated and will be removed in version 1.0; use #send_request instead\n" \
            "Client.send called from #{Gem.location_of_caller.join(':')}\n"
      warn msg unless Gem::Deprecate.skip
      send_request(request)
    end

    def inject_saml(doc)
      saml_doc = Nokogiri::XML(File.read(@saml)).root
      doc.at_xpath(
        '//wsse:Security',
        wsse: 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
      ) << saml_doc
    end

    def remove_must_understand(doc)
      node = doc.at_xpath(
        '//wsse:Security',
        wsse: 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
      ).attributes['mustUnderstand']
      node.remove if node
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

      if @keystore.all.length > 0
        request.auth.ssl.cert_key          = @keystore.all.first.key
        request.auth.ssl.cert_key_password = @keypass
        request.auth.ssl.cert              = @keystore.all.first.certificate
        request.auth.ssl.ca_cert_file      = @cacert
        request.auth.ssl.verify_mode       = :peer
      else
        # TODO: this can't really be correct
        request.auth.ssl.verify_mode = :none
      end

      request.body = body
      request.headers = headers
      request
    end

    def crypto_options
      {
        server: {
          certificate: @keystore.all.last.certificate,
          keytransport_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::RSA_PKCS1_15,
          cipher_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::AES128
        },
        client: {
          certificate: @keystore.all.first.certificate,
          private_key: @keystore.all.first.key,
          digest_algorithm: 'http://www.w3.org/2000/09/xmldsig#sha1',
          signature_algorithm: 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
        }
      }
    end

    def parse_xml_strictly(xml_string)
      begin
        xml = Nokogiri::XML(
          xml_string,
          nil,
          nil,
          Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET
        )
      rescue Nokogiri::XML::SyntaxError
        raise SOAPError.new('Unable to parse SOAP message', xml_string)
      end
      xml
    end

    def serialize_document(doc)
      doc.serialize(
        encoding: 'UTF-8',
        save_with: Nokogiri::XML::Node::SaveOptions::AS_XML
      )
    end

    def parse_body(xml)
      doc = parse_xml_strictly(xml)
      doc.at_xpath('/soapenv:Envelope/soapenv:Body',
                   soapenv: 'http://schemas.xmlsoap.org/soap/envelope/')
    end

    def multipart_boundary(headers)
      return nil unless headers.key?('Content-Type')
      Mail::Field.new('Content-Type', headers['Content-Type']).parameters['boundary']
    end

    def multipart_sections(response)
      boundary = multipart_boundary(response.headers)
      return if boundary.nil?
      Mail::Part.new(
        headers: response.headers,
        body: response.body
      ).body.split!(boundary).parts
    end

    def multipart?(response)
      !(response.headers['Content-Type'] =~ /^multipart/im).nil?
    end

    def get_body(response)
      if multipart?(response)
        parts = multipart_sections(response)
        unless parts.nil?
          # might consider looking for application/xml+xop payload in there
          return parts.first.body.to_s
        end
      end

      # otherwise just return the body
      response.body
    end

    def process_response(request, response)
      body = get_body(response)

      # we could check the response content-type to make sure it's XML, but they don't seem
      # to send any HTTP headers back, so we'll instead rely on strict XML parsing instead
      doc = parse_xml_strictly(body)
      check_soap_errors(doc, response)

      data = VBMS.decrypt_message_xml_ruby(
        doc.to_xml,
        @keystore.all.first.key,
        @keypass
      )

      log(:decrypted_message, decrypted_data: data, request: request)

      doc = parse_xml_strictly(data)
      request.handle_response(doc)
    end

    def check_soap_errors(doc, response)
      # the envelope should be the root node of the document
      soap = doc.at_xpath('/soapenv:Envelope', VBMS::XML_NAMESPACES)
      fail SOAPError.new('No SOAP envelope found in response', response.body) if
        soap.nil?

      fail SOAPError.new('SOAP Fault returned', response.body) if
        soap.at_xpath('//soapenv:Fault', VBMS::XML_NAMESPACES)
    end
  end
end
