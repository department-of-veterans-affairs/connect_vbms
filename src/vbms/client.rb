require 'soap-scum'

module VBMS
  # rubocop:disable Metrics/ClassLength
  class Client
    attr_reader :endpoint_url

    def self.from_env_vars(logger: nil, env_name: 'test')
      env_dir = File.join(get_env('CONNECT_VBMS_ENV_DIR'), env_name)
      VBMS::Client.new(
        get_env('CONNECT_VBMS_URL'),
        env_path(env_dir, 'CONNECT_VBMS_SAML_FILE'),
        env_path(env_dir, 'CONNECT_VBMS_SERVER_KEY_FILE'),
        env_path(env_dir, 'CONNECT_VBMS_IMPORT_KEY_FILE'),
        get_env('CONNECT_VBMS_IMPORT_KEY_PASS'),
        # security in transport
        env_path(env_dir, 'CONNECT_VBMS_HTTPS_KEY_FILE', allow_empty: true),
        get_env('CONNECT_VBMS_HTTPS_KEY_PASS', allow_empty: true),
        env_path(env_dir, 'CONNECT_VBMS_HTTPS_CERT_FILE', allow_empty: true),
        env_path(env_dir, 'CONNECT_VBMS_HTTPS_CACERT_FILE', allow_empty: true),
        logger
      )
    end

    def initialize(endpoint_url, saml, server_key, client_key, client_keypass, 
                   https_key, https_keypass, https_cert, https_cacert, logger = nil)
      @endpoint_url = endpoint_url
      @saml = saml
      @server_key = server_key
      @client_key = client_key
      @client_keypass = client_keypass
      
      @keystore = SoapScum::KeyStore.new
      @keystore.add_pubkey(@server_key)
      @keystore.add_pc12(@client_key, @client_keypass)

      @processor = SoapScum::MessageProcessor.new(@keystore)

      @https_key = https_key
      @https_keypass = https_keypass
      @https_cacert = https_cacert

      @logger = logger
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

    def log(event, data)
      @logger.log(event, data) if @logger
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def send_request(request)
      unencrypted_xml = request.render_xml

      log(
        :unencrypted_xml,
        unencrypted_body: unencrypted_xml
      )

      # output = VBMS.encrypted_soap_document_xml(
      #   unencrypted_xml,
      #   @keyfile,
      #   @keypass,
      #   request.name)
      # ---------------------


      # soap_doc = @processor.wrap_in_soap(Nokogiri::XML(unencrypted_xml))
      # soap_doc = @processor.wrap_in_soap(Nokogiri::XML(unencrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT))
      unencrypted_doc = parse_xml_strictly(unencrypted_xml)
      soap_doc = @processor.wrap_in_soap(unencrypted_doc)
      output = @processor.encrypt(soap_doc,
        crypto_options,
        soap_doc.at_xpath(
          '/soapenv:Envelope/soapenv:Body',
          soapenv: SoapScum::XMLNamespaces::SOAPENV).children)

      # -------------------------
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
      if @https_key
        request.auth.ssl.cert_key_file = @https_key
        request.auth.ssl.cert_key_password = @https_keypass
        request.auth.ssl.cert_file = @https_cert
        request.auth.ssl.ca_cert_file = @https_cacert
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

    def crypto_options
      {
        server: {
            certificate: @keystore.all.first.certificate,
            keytransport_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::RSA_PKCS1_15,
            cipher_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::AES128
        },
        client: {
            certificate: @keystore.all.last.certificate,
            private_key: @keystore.all.last.key,
            digest_algorithm: "http://www.w3.org/2000/09/xmldsig#sha1",
            signature_algorithm: "http://www.w3.org/2000/09/xmldsig#rsa-sha1"
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

    def get_body(response)
      if response.multipart?
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
      full_doc = parse_xml_strictly(body)
      check_soap_errors(full_doc, response)

      begin
        data = Tempfile.open('log') do |out_t|
          VBMS.decrypt_message_xml(body, @keyfile, @keypass, out_t.path)
        end
      rescue ExecutionError
        raise SOAPError.new('Unable to decrypt SOAP response', body)
      end

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
