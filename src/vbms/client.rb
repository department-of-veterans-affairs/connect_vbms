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
      subfields = headers['Content-Type'].split(/;\s+/)

      return nil unless subfields.detect { |x| /^boundary="([^"]+)"/ =~ x }
      Regexp.last_match(1)
    end

    def split_part_into_headers_and_body(message)
      return { headers: nil, body: message } unless message =~ /\r\n\r\n/

      header_section, body_text = message.split(/\r\n\r\n/, 2)
      headers = Hash[header_section.split(/\r\n/).reject(&:blank?).map { |s| s.scan(/^(\S+): (.+)/).first }]
      { headers: headers, body: body_text }
    end

    # rubocop:disable Metrics/AbcSize
    def multipart_sections(response)
      boundary = multipart_boundary(response.headers)
      # response.body.split(/(\r\n)?\-\-#{boundary}(\-\-)?(\r\n)?/).map {|p| split_part_into_headers_and_body(p) }

      # useful regexp lifted from the Mail gem
      parts_regex = /
        (?:                    # non-capturing group
          \A                |  # start of string OR
          \r\n                 # line break
         )
        (
          --#{Regexp.escape(boundary || "")}  # boundary delimiter
          (?:--)?                             # with non-capturing optional closing
        )
        (?=\s*$)                              # lookahead matching zero or more spaces followed by line-ending
      /x

      # splits string into body, separator pairs; do we care about preamble, conclusion strings
      parts = response.body.split(parts_regex).each_slice(2).to_a

      if parts.size > 1
        final_separator = parts[-2].last
        parts << [""] if final_separator != "--#{boundary}--"
      end

      parts.map { |p| split_part_into_headers_and_body(p.first) }.reject { |x| x[:body].blank? }
    end
    # rubocop:enable Metrics/AbcSize

    def get_body(response)
      if response.multipart?
        parts = multipart_sections(response)

        unless parts.nil?
          # might consider looking for application/xml+xop payload in the headers
          return parts.first[:body]
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
