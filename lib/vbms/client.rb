# frozen_string_literal: true

module VBMS
  class Client
    attr_reader :base_url

    def initialize(base_url:,
                   keypass:,
                   client_keyfile:,
                   server_cert:,
                   saml:,
                   ca_cert: nil,
                   logger: nil,
                   css_id: nil,
                   station_id: nil,
                   proxy_base_url: nil,
                   use_forward_proxy: false)

      @base_url = base_url
      @keyfile = client_keyfile
      @saml = saml
      @keypass = keypass
      @cacert = ca_cert
      @server_key = server_cert
      @logger = logger
      @css_id = css_id
      @station_id = station_id
      @proxy_base_url = proxy_base_url
      @use_forward_proxy = use_forward_proxy

      SoapScum::WSSecurity.configure(
        client_keyfile: client_keyfile,
        server_cert: server_cert,
        keypass: keypass
      )
    end

    def self.from_env_vars(logger: nil, css_id: nil, station_id: nil, env_name: "test", use_forward_proxy: false)
      env_dir = File.join(get_env("CONNECT_VBMS_ENV_DIR"), env_name)

      VBMS::Client.new(
        base_url: get_env("CONNECT_VBMS_BASE_URL"),
        keypass: get_env("CONNECT_VBMS_KEYPASS", allow_empty: true),
        client_keyfile: env_path(env_dir, "CONNECT_VBMS_CLIENT_KEYFILE"),
        server_cert: env_path(env_dir, "CONNECT_VBMS_SERVER_CERT", allow_empty: true),
        ca_cert: env_path(env_dir, "CONNECT_VBMS_CACERT", allow_empty: true),
        saml: env_path(env_dir, "CONNECT_VBMS_SAML"),
        css_id: css_id,
        station_id: station_id,
        use_forward_proxy: use_forward_proxy,
        proxy_base_url: get_env("CONNECT_VBMS_PROXY_BASE_URL", allow_empty: true),
        logger: logger
      )
    end

    def self.get_env(env_var_name, allow_empty: false)
      value = ENV[env_var_name]
      raise EnvironmentError, "#{env_var_name} must be set" if !allow_empty && (value.nil? || value.empty?)

      value
    end

    def self.env_path(env_dir, env_var_name, allow_empty: false)
      value = get_env(env_var_name, allow_empty: allow_empty)
      return nil if value.nil?

      File.join(env_dir, value)
    end

    def log(event, data)
      @logger&.log(event, data)
    end

    def send_request(request)
      encrypted_doc = SoapScum::WSSecurity.encrypt(request.soap_doc, request.signed_elements)
      inject_header_content(encrypted_doc, request)
      inject_saml(encrypted_doc)
      remove_must_understand(encrypted_doc)
      serialized_doc = serialize_document(encrypted_doc)
      body = create_body(request, serialized_doc)

      # If we have a sidecar proxy enabled, send the request to the
      # proxy URL instead of directly to VBMS.
      # the proxy uses 'envoy-prefix-requestName' to gather metrics
      # https://www.envoyproxy.io/docs/envoy/latest/api-v1/route_config/vcluster.html
      url = @use_forward_proxy ? request.endpoint_url("#{@proxy_base_url}/envoy-prefix-#{request.name}") : request.endpoint_url(@base_url)
      headers = { "Content-Type" => content_type(request) }
      http_request = build_request(url,
                                   body, headers)

      HTTPI.log = false
      response = HTTPI.post(http_request)

      log(
        :request,
        response_code: response.code,
        request_body: serialized_doc.to_s,
        response_body: response.body,
        request: request
      )

      raise VBMS::HTTPError.from_http_error(response.code, response.body, request) if response.code != 200

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

      # replace user headers if needed
      user_element = doc.at_xpath("//etc:cssUserName", "etc" => "http://vbms.vba.va.gov/external")
      station_element = doc.at_xpath("//etc:cssStationId", "etc" => "http://vbms.vba.va.gov/external")
      user_element.content = @css_id if @css_id && user_element
      station_element.content = @station_id if @station_id && station_element

      doc
    end

    def remove_must_understand(doc)
      node = doc.at_xpath(
        "//wsse:Security",
        wsse: "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
      ).attributes["mustUnderstand"]
      node&.remove
    end

    def create_body(request, doc)
      if request.multipart?
        filepath = request.multipart_file
        filename = File.basename(filepath)
        content = File.read(filepath)
        VBMS.load_erb("mtom_request.erb").result(binding)
      else
        VBMS.load_erb("request.erb").result(binding)
      end
    end

    def build_request(endpoint_url, body, headers = {})
      if @use_forward_proxy
        # If we're using a forward proxy, add the eventual
        # destination host as a header.
        headers["Host"] = @base_url.gsub("https://", "").gsub("http://", "")
      end

      request = HTTPI::Request.new(endpoint_url)

      request.open_timeout               = 10 # seconds
      request.read_timeout               = 1200 # seconds
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
      rescue Nokogiri::XML::SyntaxError
        raise SOAPError.new("Unable to parse SOAP message", xml_string)
      end
      xml
    end

    def serialize_document(doc)
      doc.serialize(
        encoding: "UTF-8",
        save_with: Nokogiri::XML::Node::SaveOptions::AS_XML
      )
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
      raise SOAPError.new("No SOAP envelope found in response", response.body) if
        soap.nil?

      raise SOAPError.new("SOAP Fault returned", response.body) if
        soap.at_xpath("//soapenv:Fault", VBMS::XML_NAMESPACES)

      soap = doc.at_xpath("/soapenv:Envelope/soapenv:Body",
                          soapenv: "http://schemas.xmlsoap.org/soap/envelope/")
      raise SOAPError.new("No SOAP body found in response", response.body) if
        soap.nil?
    end
  end
end
