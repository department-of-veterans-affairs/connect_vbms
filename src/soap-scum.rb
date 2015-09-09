require 'base64'
require 'nokogiri'
require 'xmldsig'

module SoapScum
  module XMLNamespaces
    SOAPENV = "http://schemas.xmlsoap.org/soap/envelope/"
    WSSE = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
    WSSE11 = "http://docs.oasis-open.org/wss/oasis-wss-wssecurity-secext-1.1.xsd"
    WSU = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
    DS = "http://www.w3.org/2000/09/xmldsig#"
    XENC = "http://www.w3.org/2001/04/xmlenc#"
  end

  class KeyStore
    CertificateAndKey = Struct.new(:certificate, :key)

    def initialize
      @by_subject = {}
    end

    def all
      @by_subject.values
    end

    def add_pc12(path, keypass = "")
      pkcs12 = OpenSSL::PKCS12.new(File.read(path), keypass)
      entry = CertificateAndKey.new(pkcs12.certificate, pkcs12.key)

      @by_subject[x509_to_normalized_subject(pkcs12.certificate)] = entry
    end

    def get_key(keyinfo_node)
      needle = keyinfo_to_normalized_subject(keyinfo_node)
      @by_subject[needle].key
    end

    def get_certificate(keyinfo_node)
      needle = keyinfo_to_normalized_subject(keyinfo_node)
      @by_subject[needle].certificate
    end

   private
    # Takes an x509 certificate and returns an array sorted in an order that
    # allows for matching against other normalized subjects.
    def x509_to_normalized_subject(certificate)
      normalized_subject = certificate.subject.to_a.map {|name, value, _| [name, value] }.sort_by {|x| x[0] }
      normalized_subject << ['SerialNumber', certificate.serial.to_s ]
    end

    def keyinfo_to_normalized_subject(keyinfo_node)
      subject = keyinfo_node.at(
        '/ds:KeyInfo/wsse:SecurityTokenReference/ds:X509Data/ds:X509IssuerSerial/ds:X509IssuerName',
        ds: XMLNamespaces::DS,
        wsse: XMLNamespaces::WSSE)
      serial = keyinfo_node.at(
        '/ds:KeyInfo/wsse:SecurityTokenReference/ds:X509Data/ds:X509IssuerSerial/ds:X509SerialNumber',
        ds: XMLNamespaces::DS,
        wsse: XMLNamespaces::WSSE)

      normalized_subject = subject.inner_text.split(',').map {|x| x.split('=')}.sort_by{|x| x[0]}
      normalized_subject << ['SerialNumber', serial.inner_text ]
    end

    def keyinfo_has_cert?(keyinfo_node)
    end
  end

  class MessageProcessor
    module CryptoAlgorithms
      RSA_PKCS1_15 = 'http://www.w3.org/2001/04/xmlenc#rsa-1_5'
      RSA_OAEP = 'http://www.w3.org/2001/04/xmlenc#rsa-oaep-mgf1p'
      # TODO(awong): Add triple-des support for xmlenc 1.0 compliance.
      AES128 = 'http://www.w3.org/2001/04/xmlenc#aes128-cbc'
      AES256 = 'http://www.w3.org/2001/04/xmlenc#aes256-cbc'
    end

    def initialize(keystore)
      @keystore = keystore
    end

    # Creats a soap message wrapping the root node of the contents_doc.
    #
    # SOAP messages have the format
    #
    # <Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
    #   <Body>
    #   <!-- Content goes here -->
    #   </Body>
    # </Envelope>
    #
    # The header element is optional without mustUnderstand so this does not
    # populate it.
    #
    # TODO(awong): Add mustUnderstand support.
    # TODO(astone): add ws:Id
    def wrap_in_soap(contents_doc)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml['soapenv'].Envelope('xmlns:soapenv' => XMLNamespaces::SOAPENV) do
            xml['soapenv'].Body do
              if !contents_doc.nil?
                xml.parent << contents_doc.root.clone
              end
            end
          end
        end
        builder.doc
    end

    def encrypt(soap_doc, certificate, private_key, keytransport_algorithm, cipher_algorithm, nodes_to_encrypt, validity: 5.minutes)
      envelope = soap_doc.xpath('/soapenv:Envelope', soapenv: XMLNamespaces::SOAPENV)

      # Ensure there is a header node.
      header = envelope.at_xpath('/soapenv:Header', soapenv: XMLNamespaces::SOAPENV)
      if header.nil?
        header_builder = Nokogiri::XML::Builder.new do |xml|
          xml["soapenv"].Header('xmlns:soapenv' => XMLNamespaces::SOAPENV)
        end
        envelope.children.first.add_previous_sibling(header_builder.doc.root)
        header = envelope.children.first
      end

      nodes_to_sign = soap_doc.at_xpath('/soapenv:Envelope/soapenv:Body',
                                        soapenv: SoapScum::XMLNamespaces::SOAPENV).children
      # Create the wsse:Security header.
      #   * Generate timestammp element.
      #   * Create xmlenc template
      #   * Create xmldsig template
      Nokogiri::XML::Builder.with(soap_doc.at('/soap:Envelope/soap:Header', soap: XMLNamespaces::SOAPENV)) do |xml|
        xml['wsse'].Security('xmlns:wsse' => XMLNamespaces::WSSE,
                             'xmlns:wsu' => XMLNamespaces::WSU,
) do
          add_xmlenc_template(xml, certificate, keytransport_algorithm, cipher_algorithm, nodes_to_encrypt)
          # TODO(awong): Allow configurable digest and signature methods.
          add_xmldsig_template(xml, certificate, "http://www.w3.org/2000/09/xmldsig#sha1", "http://www.w3.org/2000/09/xmldsig#rsa-sha1", nodes_to_sign)

          # Add wsu:Timestamp
          timestamp_id = "TS-#{generate_id}"
          xml['wsu'].Timestamp('wsu:Id' => timestamp_id) do
            # Using localtime technically follows spec but seems to break
            # various parsers.
            now = Time.now.utc
            xml['wsu'].Created now.xmlschema
            xml['wsu'].Expires (now + validity).xmlschema
          end

        end
      end

      # Ensure IDs exist on elements like body.
      # Perform actual signature on plaintext.
      # Perform actual encryption
      # unsigned_document = Xmldsig::SignedDocument.new(
      #   soap_doc.serialize(
      #     encoding: 'UTF-8',
      #     save_with: Nokogiri::XML::Node::SaveOptions::AS_XML))
      # unsigned_document.sign(private_key)
      sign_soap_doc(soap_doc, private_key)
    end

   private

    def sign_soap_doc(soap_doc, private_key)
      Xmldsig::SignedDocument.new(
        soap_doc.serialize(
          encoding: 'UTF-8',
          save_with: Nokogiri::XML::Node::SaveOptions::AS_XML
        )
      ).sign(private_key)
    end

    def generate_encrypted_data(node, encrypted_node_id, key_id, symmetric_key, cipher_algorithm, cipher)
      cipher.reset
      cipher.encrypt
      cipher.key = symmetric_key
      iv = cipher.random_iv

      raw_xml = node.serialize(encoding: 'UTF-8', save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      cipher_text = iv + cipher.update(raw_xml) + cipher.final
      builder = Nokogiri::XML::Builder.new do |xml|
        xml['xenc'].EncryptedData('xmlns:xenc' => 'http://www.w3.org/2001/04/xmlenc#', Id: encrypted_node_id, Type: "http://www.w3.org/2001/04/xmlenc#Content") do
          xml['xenc'].EncryptionMethod(Algorithm: cipher_algorithm)
          xml['ds'].KeyInfo('xmlns:ds' => XMLNamespaces::DS) do
            xml['wsse'].SecurityTokenReference('xmlns:wsse' => XMLNamespaces::WSSE,
                                               'xmlns:wsse11' => XMLNamespaces::WSSE11,
                                               'wsse11:TokenType' => 'http://docs.oasis-open.org/wss/oasis-wss-soap-message-security-1.1#EncryptedKey') do
              xml['wsse'].Reference(URI: "##{key_id}")
            end
          end
          xml['xenc'].CipherData do
            xml['xenc'].CipherValue Base64.strict_encode64(cipher_text)
          end
        end
      end
      builder.doc.root
    end

    def get_block_cipher(cipher_algorithm)
      case cipher_algorithm
      when CryptoAlgorithms::AES128
        return OpenSSL::Cipher::AES128.new(:CBC)
      when CryptoAlgorithms::AES256
        return OpenSSL::Cipher::AES256.new(:CBC)
      else
        raise "Unknown Cipher: #{cipher_algorithm}"
      end
    end

    def generate_id
      SecureRandom.hex(5)
    end

    # Takes an XMLBuilder and adds the XML Encryption template.
    def add_xmlenc_template(xml, certificate, keytransport_algorithm, cipher_algorithm, nodes_to_encrypt)
      # #5.4.1 Lists the valid ciphers and block sizes.
      # Generate a secure key as per ruby docs.
      cipher = get_block_cipher(cipher_algorithm)
      cipher.encrypt
      symmetric_key = cipher.random_key

      key_id = "EK-#{generate_id}"
      xml['xenc'].EncryptedKey('xmlns:xenc' => 'http://www.w3.org/2001/04/xmlenc#', Id: key_id) do
        xml['xenc'].EncryptionMethod(Algorithm: keytransport_algorithm)
        xml['ds'].KeyInfo('xmlns:ds' => XMLNamespaces::DS) do
          xml['wsse'].SecurityTokenReference do
            xml['ds'].X509Data do
              xml['ds'].X509IssuerSerial do
                xml['ds'].X509IssuerName certificate.subject.to_a.map { |name,value,_| "#{name}=#{value}" }.join(',')
                xml['ds'].X509SerialNumber certificate.serial.to_s
              end
            end
          end
        end

        xml['xenc'].CipherData do
          xml['xenc'].CipherValue Base64.strict_encode64(certificate.public_key.public_encrypt(symmetric_key))
        end

        xml['xenc'].ReferenceList do
          nodes_to_encrypt.each do |node|
            encrypted_node_id = "ED-#{generate_id}"
            encrypted_node = generate_encrypted_data(node, encrypted_node_id, key_id, symmetric_key, cipher_algorithm, cipher)
            xml['xenc'].DataReference(URI: "##{encrypted_node_id}")
            node.add_previous_sibling(encrypted_node)
            node.remove
          end
        end
      end
    end

    def add_xmldsig_template(xml, certificate, digest_method, signature_method, nodes_to_sign)
      xml['ds'].Signature('xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#', Id: "EK-#{generate_id}") do
        xml['ds'].SignedInfo do
          # TODO(awong): Allow modification of CanonicalizationMethod.
          xml['ds'].CanonicalizationMethod(Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") do
            xml['ec'].InclusiveNamespaces('xmlns:ec' => "http://www.w3.org/2001/10/xml-exc-c14n#", PrefixList: "soapenv v4")
          end
          xml['ds'].SignatureMethod(Algorithm: signature_method)
          # [TODO astone]         This still needs to reference nodes to sign.
          nodes_to_sign.each do |node|
            xml['ds'].Reference(URI: "##{node.attr('wsu:Id')}") do
             xml['ds'].Transforms do
               xml['ds'].Transform(Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") do
                 xml['ec'].InclusiveNamespaces('xmlns:ec' => "http://www.w3.org/2001/10/xml-exc-c14n#", PrefixList: "soapenv v4")
               end
             end
             xml['ds'].DigestMethod(Algorithm: digest_method)
             xml['ds'].DigestValue
            end
          end
        end
        xml['ds'].SignatureValue
        xml['ds'].KeyInfo('xmlns:ds' => XMLNamespaces::DS, Id: "KI-#{generate_id}") do
          xml['wsse'].SecurityTokenReference('wsu:Id' => "STR-#{generate_id}") do
            xml['ds'].X509Data do
              xml['ds'].X509IssuerSerial do
                xml['ds'].X509IssuerName certificate.subject.to_a.map { |name,value,_| "#{name}=#{value}" }.join(',')
                xml['ds'].X509SerialNumber certificate.serial.to_s
              end
            end
          end
        end
      end
    end
  end
end
