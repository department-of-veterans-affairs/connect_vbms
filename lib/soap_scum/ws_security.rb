require "xmldsig"
require "securerandom"
require "xmlenc"

module SoapScum
  ##
  # Singleton class used to encrypt and decrypt SOAP Nokogiri documents
  class WSSecurity
    class << self
      attr_reader :client_cert, :client_key

      ##
      # Used to set encryption keys and algorithms.
      #
      # client_keyfile - filepath for PKCS12 keyfile containing the client private key and X509 public certificate
      # server_cert - filepath for X509 public server certificate file
      # keypass - password to keyfiles
      # keytransport_algorithm -
      # cipher_algorithm
      # digest_algorithm -
      # signature_algorithm -
      # expires_in - milliseconds before request is invalid
      #
      def configure(client_keyfile:,
                    server_cert:,
                    keypass:,
                    keytransport_algorithm: SoapScum::CryptoAlgorithms::RSA_PKCS1_15,
                    cipher_algorithm: SoapScum::CryptoAlgorithms::AES128,
                    expires_in: 300)

        client_keyfile = OpenSSL::PKCS12.new(File.read(client_keyfile), keypass)
        @client_cert = client_keyfile.certificate
        @client_key = client_keyfile.key

        @server_cert = OpenSSL::X509::Certificate.new(File.read(server_cert))

	if ENV["CONNECT_VBMS_SHA256"]
		is_sha256 = "true".casecmp(ENV["CONNECT_VBMS_SHA256"])
	else
		is_sha256 = false
	end
      
        @keytransport_algorithm = keytransport_algorithm
        @cipher_algorithm = cipher_algorithm
        @digest_algorithm = is_sha256 ? SoapScum::CryptoAlgorithms::SHA256 : SoapScum::CryptoAlgorithms::SHA1
        @signature_algorithm = is_sha256 ? SoapScum::CryptoAlgorithms::RSA_SHA256 : SoapScum::CryptoAlgorithms::RSA_SHA1
        @expires_in = expires_in
      end

      ##
      # Encrypt a SOAP Nokogiri::XML::Document according to the WSSecurity spec.
      def encrypt(soap_doc, nodes)
        stripped_xml = soap_doc.to_xml.gsub(/^\s*/, "").gsub(/\s*$/, "")
        soap_doc = Nokogiri::XML(stripped_xml)

        verify_header_node(soap_doc)
        add_timestamp_node(soap_doc)

        # Double encryption must not be used on operations uploadDocument and updateDocument.
        return soap_doc if nodes.empty?

        Nokogiri::XML::Builder.with(soap_doc.at("/soap:Envelope/soap:Header/wsse:Security",
                                                soap: XMLNamespaces::SOAPENV,
                                                "xmlns:wsse" => XMLNamespaces::WSSE,
                                                "xmlns:wsu" => XMLNamespaces::WSU,
                                                "xmlns:xenc" => XMLNamespaces::XENC)) do |xml|
          add_xmlenc_template(xml)

          documents = nodes.map do |xpath, ns, _modifier|
            document = soap_doc.at(xpath, ns)
            document.add_namespace_definition "wsu", XMLNamespaces::WSU
            document["wsu:Id"] = generate_body_id
            document
          end

          add_xmldsig_template(xml, [timestamp_node(soap_doc)] + documents)
        end

        soap_doc = sign_soap_doc(soap_doc)

        nodes_to_encrypt = nodes.map do |xpath, ns, modifier|
          [soap_doc.at_xpath(xpath, ns), modifier]
        end

        Nokogiri::XML::Builder.with(soap_doc.at("*//[Id=#{encrypted_key_id}]",
                                                soap: XMLNamespaces::SOAPENV,
                                                "xmlns:wsse" => XMLNamespaces::WSSE,
                                                "xmlns:wsu" => XMLNamespaces::WSU,
                                                "xmlns:xenc" => XMLNamespaces::XENC)) do |xml|
          encrypt_references(xml, nodes_to_encrypt)
        end

        soap_doc
      end

      def decrypt(xml)
        encrypted_doc = Xmlenc::EncryptedDocument.new(xml)

        # TODO(awong): Signature verification.
        # TODO(awong): Timestamp validation.

        encrypted_doc.decrypt(@client_key)
      end

      private

      def generate_block_cipher
        case @cipher_algorithm
        when CryptoAlgorithms::AES128
          OpenSSL::Cipher::AES128.new(:CBC)
        when CryptoAlgorithms::AES256
          OpenSSL::Cipher::AES256.new(:CBC)
        else
          fail "Unknown Cipher: #{@cipher_algorithm}"
        end
      end

      def block_cipher
        @block_cipher ||= generate_block_cipher
      end

      def iv
        @iv ||= SecureRandom.random_bytes(block_cipher.iv_len)
      end

      def symmetric_key
        @symmetric_key ||= SecureRandom.random_bytes(block_cipher.key_len)
      end

      def signature_id
        @signature_id ||= "SIG-#{generate_id}"
      end

      def key_info_id
        @key_info_id ||= "KI-#{generate_id}"
      end

      def security_token_id
        @security_token_id ||= "STR-#{generate_id}"
      end

      def encrypted_data_id
        @encrypted_data_id ||= "ED-#{generate_id}"
      end

      def generate_id
        SecureRandom.hex(5)
      end

      def generate_body_id
        "id-#{generate_id}"
      end

      def timestamp_id
        @timestamp_id ||= "TS-#{generate_id}"
      end

      def encrypted_key_id
        @encrypted_key_id ||= "EK-#{generate_id}"
      end

      def format_cert_xml(certificate)
        certificate.issuer.to_a.reverse.map { |name, value, _| "#{name}=#{value}" }.join(",")
      end

      def timestamp_node(soap_doc)
        soap_doc.at_xpath(
          "/soapenv:Envelope/soapenv:Header/wsse:Security/wsu:Timestamp",
          soapenv: XMLNamespaces::SOAPENV,
          "xmlns:wsse" => XMLNamespaces::WSSE,
          "xmlns:wsu" => XMLNamespaces::WSU)
      end

      def sign_soap_doc(soap_doc)
        signed_doc = Xmldsig::SignedDocument.new(soap_doc)
        signed_doc.sign(@client_key)
        signed_doc.document
      end

      def encrypt_references(xml, nodes_to_encrypt)
        xml["xenc"].ReferenceList do
          nodes_to_encrypt.each do |node, modifier|
            encrypt_node = modifier == "Element" ? node : node.children

            encrypted_node = generate_encrypted_data(encrypt_node, modifier)

            if modifier == "Element"
              node.replace(encrypted_node)
            else
              node.children.each(&:remove)
              node << encrypted_node
            end

            xml["xenc"].DataReference(URI: "##{encrypted_data_id}")
          end
        end
      end

      def generate_encrypted_data(node, modifier)
        raw_xml = node.to_xml(
          save_with: (Nokogiri::XML::Node::SaveOptions::AS_XML |
                      Nokogiri::XML::Node::SaveOptions::NO_DECLARATION))

        block_cipher.encrypt
        block_cipher.padding = 0
        block_cipher.iv = iv
        block_cipher.key = symmetric_key
        cipher_text = iv + block_cipher.update(add_xmlenc_padding(block_cipher.block_size, raw_xml)) + block_cipher.final

        builder = Nokogiri::XML::Builder.new do |xml|
          xml["xenc"].EncryptedData(
            "xmlns:xenc" => 'http://www.w3.org/2001/04/xmlenc#',
            Id: encrypted_data_id, Type:
            "http://www.w3.org/2001/04/xmlenc##{modifier}"
          ) do
            xml["xenc"].EncryptionMethod(Algorithm: @cipher_algorithm)
            xml["ds"].KeyInfo("xmlns:ds" => XMLNamespaces::DS) do
              xml["wsse"].SecurityTokenReference(
                "xmlns:wsse" => XMLNamespaces::WSSE,
                "xmlns:wsse11" => XMLNamespaces::WSSE11,
                "wsse11:TokenType" => 'http://docs.oasis-open.org/wss/oasis-wss-soap-message-security-1.1#EncryptedKey'
              ) do
                xml["wsse"].Reference(URI: "##{encrypted_key_id}")
              end
            end

            xml["xenc"].CipherData do
              xml["xenc"].CipherValue Base64.strict_encode64(cipher_text)
            end
          end
        end

        builder.doc.root
      end

      def verify_header_node(soap_doc)
        envelope = soap_doc.xpath("/soapenv:Envelope", soapenv: XMLNamespaces::SOAPENV)

        # Ensure there is a header node.
        header = envelope.at_xpath("/soapenv:Header", soapenv: XMLNamespaces::SOAPENV)

        if header.nil?
          header_builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
            xml["soapenv"].Header("xmlns:soapenv" => XMLNamespaces::SOAPENV)
          end
          envelope.children.first.add_previous_sibling(header_builder.doc.root)
          envelope.children.first
        end
      end

      def add_timestamp_node(soap_doc)
        Nokogiri::XML::Builder.with(soap_doc.at("/soap:Envelope/soap:Header", soap: XMLNamespaces::SOAPENV)) do |xml|
          xml["wsse"].Security("xmlns:wsse" => XMLNamespaces::WSSE,
                               "xmlns:wsu" => XMLNamespaces::WSU) do
            xml["wsu"].Timestamp("wsu:Id" => timestamp_id,
                                 "xmlns:wsse" => XMLNamespaces::WSSE,
                                 "xmlns:wsu" => XMLNamespaces::WSU
                                ) do
              now = Time.now.utc
              xml["wsu"].Created now.xmlschema(3)
              xml["wsu"].Expires((now + @expires_in).xmlschema(3))
            end
          end
        end
      end

      ##
      # Takes an XMLBuilder and adds the XML Encryption template.
      def add_xmlenc_template(xml)
        xml["xenc"].EncryptedKey("xmlns:xenc" => XMLNamespaces::XENC, Id: encrypted_key_id) do
          xml["xenc"].EncryptionMethod(Algorithm: @keytransport_algorithm)
          xml["ds"].KeyInfo("xmlns:ds" => XMLNamespaces::DS) do
            xml["wsse"].SecurityTokenReference do
              xml["ds"].X509Data do
                xml["ds"].X509IssuerSerial do
                  xml["ds"].X509IssuerName format_cert_xml(@server_cert)
                  xml["ds"].X509SerialNumber @server_cert.serial.to_s
                end
              end
            end
          end

          xml["xenc"].CipherData do
            xml["xenc"].CipherValue Base64.strict_encode64(@server_cert.public_key.public_encrypt(symmetric_key))
          end
        end
      end

      def add_xmldsig_template(xml, nodes_to_sign)
        xml["ds"].Signature("xmlns:ds" => 'http://www.w3.org/2000/09/xmldsig#', Id: signature_id) do
          xml["ds"].SignedInfo("xmlns:ds" => 'http://www.w3.org/2000/09/xmldsig#',
                               "xmlns:soapenv" => XMLNamespaces::SOAPENV) do
            # TODO(awong): Allow modification of CanonicalizationMethod.
            xml["ds"].CanonicalizationMethod(Algorithm: 'http://www.w3.org/2001/10/xml-exc-c14n#') do
              xml["ec"].InclusiveNamespaces("xmlns:ec" => 'http://www.w3.org/2001/10/xml-exc-c14n#',
                                            "PrefixList" => "cdm doc soapenv v4 xop")
            end

            xml["ds"].SignatureMethod(Algorithm: @signature_algorithm)

            nodes_to_sign.each do |node|
              xml["ds"].Reference(URI: "##{node.attr('wsu:Id')}") do
                xml["ds"].Transforms do
                  xml["ds"].Transform(Algorithm: 'http://www.w3.org/2001/10/xml-exc-c14n#') do
                    prefix_list = (node.name == "Body" ? "cdm doc v4 xop" : "wsse cdm doc soapenv v4 xop")
                    xml["ec"].InclusiveNamespaces(
                      "xmlns:ec" => 'http://www.w3.org/2001/10/xml-exc-c14n#',
                      PrefixList: prefix_list
                    )
                  end
                end
                xml["ds"].DigestMethod(Algorithm: @digest_algorithm)
                xml["ds"].DigestValue
              end
            end
          end

          xml["ds"].SignatureValue
          xml["ds"].KeyInfo("xmlns:ds" => XMLNamespaces::DS, Id: key_info_id) do
            xml["wsse"].SecurityTokenReference("wsu:Id" => security_token_id) do
              xml["ds"].X509Data do
                xml["ds"].X509IssuerSerial do
                  xml["ds"].X509IssuerName format_cert_xml(@client_cert)
                  xml["ds"].X509SerialNumber @client_cert.serial.to_s
                end
              end
            end
          end
        end
      end

      ##
      # Add xmlenc padding as specified in the xmlenc spec.
      # http://www.w3.org/TR/2002/REC-xmlenc-core-20021210/Overview.html#sec-Alg-Block
      def add_xmlenc_padding(block_size, unpadded_string)
        data = unpadded_string.dup
        fail "block size #{block_size} must be > 0." if block_size <= 0
        padding_length = (block_size - data.length % block_size)
        num_rand_bytes = padding_length - 1
        data << SecureRandom.random_bytes(num_rand_bytes) if num_rand_bytes > 0
        data << padding_length.chr  # TODO(awong): Do we encoding issues?
        data  # String is now padded.
      end
    end
  end
end
