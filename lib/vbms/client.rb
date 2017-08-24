module VBMS
  class Client
    attr_reader :base_url

    def initialize(base_url:,
                   keypass:,
                   client_keyfile:,
                   server_cert:,
                   ca_cert: nil,
                   saml:,
                   logger: nil)

      @base_url = base_url
      @keyfile = client_keyfile
      @saml = saml
      @keypass = keypass
      @cacert = ca_cert
      @server_key = server_cert
      @logger = logger

      SoapScum::WSSecurity.configure(
        client_keyfile: client_keyfile,
        server_cert: server_cert,
        keypass: keypass
      )
    end

    def self.from_env_vars(logger: nil, env_name: "test")
      env_dir = File.join(get_env("CONNECT_VBMS_ENV_DIR"), env_name)

      VBMS::Client.new(
        base_url: get_env("CONNECT_VBMS_BASE_URL"),
        keypass: get_env("CONNECT_VBMS_KEYPASS"),
        client_keyfile: env_path(env_dir, "CONNECT_VBMS_CLIENT_KEYFILE"),
        server_cert: env_path(env_dir, "CONNECT_VBMS_SERVER_CERT", allow_empty: true),
        ca_cert: env_path(env_dir, "CONNECT_VBMS_CACERT", allow_empty: true),
        saml: env_path(env_dir, "CONNECT_VBMS_SAML"),
        logger: logger
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

    def send_request(request)
      encrypted_doc = SoapScum::WSSecurity.encrypt(request.soap_doc, request.signed_elements)

      inject_header_content(encrypted_doc, request)
      inject_saml(encrypted_doc)
      remove_must_understand(encrypted_doc)
      serialized_doc = serialize_document(encrypted_doc)
      body = create_body(request, serialized_doc)

      http_request = build_request(
        request.endpoint_url(@base_url),
        body, "Content-Type" => content_type(request))

      HTTPI.log = false

      begin
        retries ||= 0
        response = HTTPI.post(http_request)
        log(
          :request,
          response_code: response.code,
          request_body: serialized_doc.to_s,
          response_body: response.body,
          request: request
        )
      rescue HTTPI::SSLError
        # If we get an SSL error from VBMS, we will
        # retry the request one time
        retry if (retries += 1) <= 1
      end

      if response.code != 200
        fail VBMS::HTTPError.new(response.code, response.body, request)
      end

      process_response(request, response)
    end

    def content_type(request)
      if request.multipart?
        "Multipart/Related; "\
          'type="application/xop+xml"; '\
          'start-info="application/soap+xml"; '\
          'boundary="boundary_1234"'
      else
        "text/xml;charset=UTF-8"
      end
    end

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
        "//wsse:Security",
        wsse: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
      ) << saml_doc
    end

    def inject_header_content(doc, request)
      request.inject_header_content(doc.at_xpath("/soapenv:Envelope/soapenv:Header"))
    end

    def remove_must_understand(doc)
      node = doc.at_xpath(
        "//wsse:Security",
        wsse: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
      ).attributes["mustUnderstand"]
      node.remove if node
    end

    # rubocop:disable Style/GuardClause
    def create_body(request, doc)
      if request.multipart?
        filepath = request.multipart_file
        filename = File.basename(filepath)
        content = File.read(filepath)
        return VBMS.load_erb("mtom_request.erb").result(binding)
      else
        return VBMS.load_erb("request.erb").result(binding)
      end
    end

    def build_request(endpoint_url, body, headers)
      request = HTTPI::Request.new(endpoint_url)

      request.open_timeout               = 300 # seconds
      request.read_timeout               = 300 # seconds
      request.auth.ssl.cert_key          = SoapScum::WSSecurity.client_key
      request.auth.ssl.cert_key_password = @keypass
      request.auth.ssl.cert              = SoapScum::WSSecurity.client_cert
      request.auth.ssl.ca_cert_file      = @cacert
      request.auth.ssl.verify_mode       = :peer
      request.body = body
      request.headers = headers

      request
    end

    def parse_xml_strictly(xml_string)
      begin
        xml = Nokogiri::XML(
          xml_string,
          nil,
          nil,
          Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET
        )
      rescue Nokogiri::XML::SyntaxError => e
        error = SOAPError.new("Unable to parse SOAP message: #{e.message}", xml_string)
        error.set_backtrace(e.backtrace)
        raise error
      end
      xml
    end

    def serialize_document(doc)
      doc.serialize(
        encoding: "UTF-8",
        save_with: Nokogiri::XML::Node::SaveOptions::AS_XML
      )
    end

    def parse_body(xml)
      doc = parse_xml_strictly(xml)
      doc.at_xpath("/soapenv:Envelope/soapenv:Body",
                   soapenv: "http://schemas.xmlsoap.org/soap/envelope/")
    end

    def process_response(request, response)
      parser = MultipartParser.new(response)
      doc = parse_xml_strictly(parser.xml_content)
      check_soap_errors(doc, response)
      data = SoapScum::WSSecurity.decrypt(doc.to_xml)

      log(:decrypted_message, decrypted_data: data, request: request)

      doc = parse_xml_strictly(data)

      request.mtom_attachment = parser.mtom_content if request.mtom_attachment?

      request.handle_response(doc)
    end

    def check_soap_errors(doc, response)
      # the envelope should be the root node of the document
      soap = doc.at_xpath("/soapenv:Envelope", VBMS::XML_NAMESPACES)
      fail SOAPError.new("No SOAP envelope found in response", response.body) if
        soap.nil?

      fail SOAPError.new("SOAP Fault returned", response.body) if
        soap.at_xpath("//soapenv:Fault", VBMS::XML_NAMESPACES)
    end
  end
end
