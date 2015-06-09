module VBMS
  class Client
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
      unecrypted_xml = request.render_xml()
      output = nil
      Tempfile.open("tmp") do |t|
        t.write(unecrypted_xml)
        t.flush()
        output = VBMS.shell_java("EncryptSOAPDocument #{t.path} #@keyfile #@keypass #{request.name}")
      end
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
        :response_code => response.code,
        :request_body => doc.to_s,
        :response_body => response.body,
        :request => response
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
      Tempfile.open("tmp") do |in_t|
        in_t.write(soap)
        in_t.flush()

        Tempfile.open("log") do |out_t|
          data = VBMS.shell_java("DecryptMessage #{in_t.path} #@keyfile #{out_t.path} #@keypass")
        end
      end

      self.log(:decrypted_message, :decrypted_data => data, :request => request)

      doc = Nokogiri::XML(data)
      return request.handle_response(doc)
    end
  end
end
