module VBMS
  class Client
    def self.from_env_vars(logger: nil, env_name: "test")
      env_dir = File.join(get_env("CONNECT_VBMS_ENV_DIR"), env_name)
      return VBMS::Client.new(
        get_env("CONNECT_VBMS_URL"),
        env_path(env_dir, "CONNECT_VBMS_KEYFILE"),
        env_path(env_dir, "CONNECT_VBMS_SAML"),
        env_path(env_dir, "CONNECT_VBMS_KEY", allow_empty: true),
        get_env("CONNECT_VBMS_KEYPASS"),
        env_path(env_dir, "CONNECT_VBMS_CACERT", allow_empty: true),
        env_path(env_dir, "CONNECT_VBMS_CERT", allow_empty: true),
        logger,
      )

    end

    def self.get_env(env_var_name, allow_empty: false)
      value = ENV[env_var_name]
      if !allow_empty && (value.nil? || value.empty?)
        raise EnvironmentError, "#{env_var_name} must be set"
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
      if @logger
        @logger.log(event, data)
      end
    end

    def send(request)
      unencrypted_xml = request.render_xml()

      self.log(
        :unencrypted_xml,
        unencrypted_body: unencrypted_xml,
      )

      output = VBMS.encrypted_soap_document_xml(unencrypted_xml, @keyfile, @keypass, request.name)
      doc = Nokogiri::XML(output)
      self.inject_saml(doc)
      self.remove_mustUnderstand(doc)

      body = self.create_body(request, doc)

      http_request = self.build_request(body, {
        'Content-Type' => 'Multipart/Related; type="application/xop+xml"; start-info="application/soap+xml"; boundary="boundary_1234"'
      })
      HTTPI.log = false
      response = HTTPI.post(http_request)

      self.log(
        :request,
        response_code: response.code,
        request_body: doc.to_s,
        response_body: response.body,
        request: request
      )

      if response.code != 200
        raise VBMS::HTTPError.new(response.code, response.body)
      end

      return self.process_response(request, response)
    end

    def inject_saml(doc)
      saml_doc = Nokogiri::XML(File.read(@saml)).root
      doc.at_xpath(
        "//wsse:Security",
        wsse: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
      ) << saml_doc
    end

    def remove_mustUnderstand(doc)
      doc.at_xpath(
        "//wsse:Security",
        wsse: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
      ).attributes["mustUnderstand"].remove
    end

    def create_body(request, doc)
      if request.is_multipart
        filepath = request.multipart_file
        filename = File.basename(filepath)
        content = File.read(filepath)
        return VBMS.load_erb("mtom_request.erb").result(binding)
      else
        return VBMS.load_erb("request.erb").result(binding)
      end
    end

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
      return request
    end

    def process_response(request, response)
      soap = response.body.match(/<soap:envelope.*?<\/soap:envelope>/im)[0]
      doc = Nokogiri::XML(soap)

      if doc.at_xpath("//soap:Fault", soap: "http://schemas.xmlsoap.org/soap/envelope/")
        raise VBMS::SOAPError.new(doc)
      end

      data = nil
      Tempfile.open("log") do |out_t|
        data = VBMS.decrypt_message_xml(soap, @keyfile, @keypass, out_t.path)
      end

      self.log(:decrypted_message, :decrypted_data => data, :request => request)

      doc = Nokogiri::XML(data)
      return request.handle_response(doc)
    end
  end
end
