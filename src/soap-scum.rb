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
    CertStruct = Struct.new(:certificate, :key)
    
    def initialize
      @by_subject = {}
    end

    def all
      @by_subject.values
    end

    def add_pc12(path, keypass = "")
      pkcs12 = OpenSSL::PKCS12.new(File.read(path), keypass)
      cert_entry = CertStruct.new(pkcs12.certificate, pkcs12.key)
      @by_subject[x509_to_normalized_subject(pkcs12.certificate)] = cert_entry

      if pkcs12.ca_certs and pkcs12.ca_certs.any?
        issuer_entry = CertStruct.new(pkcs12.ca_certs.first)
        @by_subject[x509_to_normalized_subject(pkcs12.ca_certs.first)] = issuer_entry
      end
    end

    def add_cert(path, keypass ='')
      certificate = OpenSSL::X509::Certificate.new(File.read(path))
      cert_entry = CertStruct.new(certificate, 'importkey')
      @by_subject[x509_to_normalized_subject(certificate)] = cert_entry
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
      normalized_subject = certificate.subject.to_a.reverse.map { |name, value, _| [name, value] }.sort_by { |x| x[0] }
      normalized_subject << ['SerialNumber', certificate.serial.to_s]
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

      normalized_subject = subject.inner_text.split(',').map { |x| x.split('=') }.sort_by { |x| x[0] }
      normalized_subject << ['SerialNumber', serial.inner_text]
    end

    def keyinfo_has_cert?(_keyinfo_node)
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
    attr_accessor :cipher, :key_id, :symmetric_key, :cipher_algorithm, :encrypted_elements, :iv

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
    def wrap_in_soap(contents_doc)
      contents_doc = parse_xml_strictly(contents_doc) if contents_doc.is_a?(String)

      builder = Nokogiri::XML::Builder.new do |xml|
        xml['soapenv'].Envelope('xmlns:soapenv' => XMLNamespaces::SOAPENV,
                                'xmlns:cdm' => "http://vbms.vba.va.gov/cdm",
                                'xmlns:doc' => "http://vbms.vba.va.gov/cdm/document/v4",
                                'xmlns:v4' => "http://vbms.vba.va.gov/external/eDocumentService/v4",
                                'xmlns:xop' => "http://www.w3.org/2004/08/xop/include") do
          xml['soapenv'].Body(
            'wsu:Id' => "ID-#{generate_id}",
            'xmlns:wsu' => XMLNamespaces::WSU
          ) do
            unless contents_doc.nil?
              if body_node(contents_doc)
                # compatibilty with current Request
                body_node(contents_doc).clone.children.each do |c|
                  xml.parent << c
                end
              else
                xml.parent << contents_doc.root
              end
            end
          end
        end
      end
      builder.doc
    end

    def encrypt(soap_doc, request_name, crypto_options, nodes_to_encrypt, validity: 5.minutes)
      # TODO(astone)
      # improve crypto_options messaging, make it cohesive with keystore
      # TODO(awong): Allow configurable digest and signature methods.
      # TODO(astone) update encryption parts per request

      verify_header_node(soap_doc)
      add_timestamp_node(soap_doc, validity)

      Nokogiri::XML::Builder.with(soap_doc.at('/soap:Envelope/soap:Header/wsse:Security',
                                              soap: XMLNamespaces::SOAPENV,
                                              'xmlns:wsse' => XMLNamespaces::WSSE,
                                              'xmlns:wsu' => XMLNamespaces::WSU,
                                              'xmlns:xenc' => XMLNamespaces::XENC)) do |xml|
        add_xmlenc_template(
          xml,
          crypto_options[:server][:certificate],
          crypto_options[:server][:keytransport_algorithm],
          crypto_options[:server][:cipher_algorithm]
        )
        add_xmldsig_template(
          xml,
          crypto_options[:client][:certificate],
          crypto_options[:client][:digest_algorithm],
          crypto_options[:client][:signature_algorithm],
          [timestamp_node(soap_doc), body_node(soap_doc)]
        )        
      end

      signed_doc = sign_soap_doc(soap_doc, crypto_options[:client][:private_key]).document

      # TODO
      # this could be optimized
      # The timestamp is injected before signature is applied and therefore is
      # the first node in the Security element. The WS spec says that elements 
      # should be prepended to existing elements
      relocate_timestamp(signed_doc)

      nodes_to_encrypt = [body_node(signed_doc)]
      Nokogiri::XML::Builder.with(signed_doc.at("*//[Id=#{key_id}]",
                                              soap: XMLNamespaces::SOAPENV,
                                              'xmlns:wsse' => XMLNamespaces::WSSE,
                                              'xmlns:wsu' => XMLNamespaces::WSU,
                                              'xmlns:xenc' => XMLNamespaces::XENC)) do |xml|
        encrypt_references(xml, nodes_to_encrypt)
      end

      # puts serialize_xml_strictly(signed_doc.document)
      # puts signed_doc.serialize(
        # encoding: 'UTF-8',
        # save_with: Nokogiri::XML::Node::SaveOptions::AS_XML
      # )
      # rtnstr = signed_doc.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
      signed_doc.root.serialize(save_with:0)
    end

    private

    def sign_soap_doc(soap_doc, private_key)
      signed_doc = Xmldsig::SignedDocument.new(soap_doc)
      signed_doc.sign(private_key)
      signed_doc
    end

    def get_block_cipher(cipher_algorithm)
      case cipher_algorithm
      when CryptoAlgorithms::AES128
        OpenSSL::Cipher::AES128.new(:CBC)
      when CryptoAlgorithms::AES256
        OpenSSL::Cipher::AES256.new(:CBC)
      else
        fail "Unknown Cipher: #{cipher_algorithm}"
      end
    end

    def timestamp_node(soap_doc)
      soap_doc.at_xpath(
        '/soapenv:Envelope/soapenv:Header/wsse:Security/wsu:Timestamp',
        soapenv: SoapScum::XMLNamespaces::SOAPENV,
        'xmlns:wsse' => XMLNamespaces::WSSE,
        'xmlns:wsu' => XMLNamespaces::WSU)
    end

    def body_node(doc)
      doc.at_xpath('/soapenv:Envelope/soapenv:Body',
                   soapenv: XMLNamespaces::SOAPENV,
                   'xmlns:cdm' => "http://vbms.vba.va.gov/cdm",
                   'xmlns:doc' => "http://vbms.vba.va.gov/cdm/document/v4",
                   'xmlns:v4' => "http://vbms.vba.va.gov/external/eDocumentService/v4",
                   'xmlns:xop' => "http://www.w3.org/2004/08/xop/include")
    end

    def generate_id
      SecureRandom.hex(5)
    end

    def timestamp_id
      "TS-#{generate_id}"
    end
    
    # Takes an XMLBuilder and adds the XML Encryption template.
    def add_xmlenc_template(xml, certificate, keytransport_algorithm, cipher_algorithm)
      # #5.4.1 Lists the valid ciphers and block sizes.
      self.key_id = "EK-#{generate_id}"
      self.cipher_algorithm = cipher_algorithm
      self.cipher = get_block_cipher(cipher_algorithm)    # instantiate a new Cipher
      self.cipher.encrypt                                      # set mode for Cipher
      self.iv = cipher.random_iv
      self.symmetric_key = cipher.key = SecureRandom.random_bytes(cipher.key_len)
      # self.symmetric_key = cipher.random_key # LESS secure. see 
      # https://github.com/department-of-veterans-affairs/connect_vbms-old/pull/36/files#r33154220

      xml['xenc'].EncryptedKey('xmlns:xenc' => XMLNamespaces::XENC, Id: key_id) do
        xml['xenc'].EncryptionMethod(Algorithm: keytransport_algorithm)
        xml['ds'].KeyInfo('xmlns:ds' => XMLNamespaces::DS) do
          xml['wsse'].SecurityTokenReference do
            xml['ds'].X509Data do
              xml['ds'].X509IssuerSerial do
                xml['ds'].X509IssuerName certificate.issuer.to_a.reverse.map { |name, value, _| "#{name}=#{value}" }.join(',')
                xml['ds'].X509SerialNumber certificate.serial.to_s
              end
            end
          end
        end

        xml['xenc'].CipherData do
          xml['xenc'].CipherValue Base64.strict_encode64(certificate.public_key.public_encrypt(symmetric_key))
        end
      end
    end

    def encrypt_references(xml, nodes_to_encrypt)
      self.encrypted_elements = []
      xml['xenc'].ReferenceList do
        nodes_to_encrypt.each do |node|
          encrypted_node_id = "ED-#{generate_id}"
          encrypted_node = generate_encrypted_data(node, encrypted_node_id, key_id, symmetric_key, cipher_algorithm)
          node.children.each {|child_node| child_node.remove } # remove unencrypted node
          node << encrypted_node
          xml['xenc'].DataReference(URI: "##{encrypted_node_id}")
        end
      end
    end

    def generate_encrypted_data(node, encrypted_node_id, key_id, symmetric_key, cipher_algorithm)
# debug
      # original:
      # raw_xml = node.serialize(encoding: 'UTF-8', save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)

      # body children to_xml
      # raw_xml = node.children.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)

      # raw_xml = node.children.collect(&:canonicalize).join
# /debug
      # new canonicalize approach. 
      raw_xml = ''
      node.children.each do |n|
        raw_xml << n.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0, ['soapenv'])
      end
      # raw_xml = raw_xml.chomp.squish
      # raw_xml = raw_xml.gsub("> <","><") # FURTHER STRIPPING. EW. 
# debug
puts "raw_xml to be encrypted ----------------------------"
puts raw_xml
# /debug
      # write ciphertext
      cipher_text = self.iv
      cipher_text << cipher.update(raw_xml)
      cipher_text << cipher.final

      # builder portion
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

    def add_xmldsig_template(xml, certificate, digest_method, signature_method, nodes_to_sign)
      xml['ds'].Signature('xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#', Id: "SIG-#{generate_id}") do
        xml['ds'].SignedInfo('xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#',
                             'xmlns:soapenv' => XMLNamespaces::SOAPENV
                            ) do
          # TODO(awong): Allow modification of CanonicalizationMethod.
          xml['ds'].CanonicalizationMethod(Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") do
            xml['ec'].InclusiveNamespaces('xmlns:ec' => 'http://www.w3.org/2001/10/xml-exc-c14n#',
                                          'PrefixList' => 'cdm doc soapenv v4 xop')
          end
          xml['ds'].SignatureMethod(Algorithm: signature_method)
          nodes_to_sign.each do |node|
            xml['ds'].Reference(URI: "##{node.attr('wsu:Id')}") do
              xml['ds'].Transforms do
                xml['ds'].Transform(Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#") do
                  prefix_list = (node.name == 'Body' ? 'cdm doc v4 xop' : 'wsse cdm doc soapenv v4 xop')
                  xml['ec'].InclusiveNamespaces('xmlns:ec' => "http://www.w3.org/2001/10/xml-exc-c14n#", PrefixList: prefix_list)
                end
              end
              xml['ds'].DigestMethod(Algorithm: digest_method)
              xml['ds'].DigestValue
            end
          end
        end
        xml['ds'].SignatureValue
        ki_id = "KI-#{generate_id}"
        xml['ds'].KeyInfo('xmlns:ds' => XMLNamespaces::DS, Id: ki_id) do
          str_id = "STR-#{generate_id}"
          xml['wsse'].SecurityTokenReference('wsu:Id' => str_id) do
            xml['ds'].X509Data do
              xml['ds'].X509IssuerSerial do
                xml['ds'].X509IssuerName format_cert_xml(certificate)
                xml['ds'].X509SerialNumber certificate.serial.to_s
              end
            end
          end
        end
      end
    end

    def verify_header_node(soap_doc)
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
    end

    def add_timestamp_node(soap_doc, validity)
      Nokogiri::XML::Builder.with(soap_doc.at('/soap:Envelope/soap:Header', soap: XMLNamespaces::SOAPENV)) do |xml|
        xml['wsse'].Security('xmlns:wsse' => XMLNamespaces::WSSE,
                             'xmlns:wsu' => XMLNamespaces::WSU) do
          xml['wsu'].Timestamp('wsu:Id' => timestamp_id,
                               'xmlns:wsse' => XMLNamespaces::WSSE,
                               'xmlns:wsu' => XMLNamespaces::WSU
                              ) do
            now = Time.now.utc
            xml['wsu'].Created now.xmlschema(3)
            xml['wsu'].Expires (now + validity).xmlschema(3)
          end
        end
      end
    end

    def format_cert_xml(certificate)
      certificate.subject.to_a.reverse.map do |name, value, _|
        "#{name}=#{value}"
      end.join(',')
    end

    def parse_xml_strictly(xml)
      Nokogiri::XML(xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    end

    def serialize_xml_strictly(xmldoc)
      xmldoc.serialize(
        encoding: 'UTF-8',
        save_with: Nokogiri::XML::Node::SaveOptions::AS_XML
      )
    end

    def relocate_timestamp(doc)
      timestamp = timestamp_node(doc)
      dsig = doc.at('/soap:Envelope/soap:Header/wsse:Security/ds:Signature',
                                              soap: XMLNamespaces::SOAPENV,
                                              'xmlns:wsse' => XMLNamespaces::WSSE,
                                              'xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#')
      dsig.add_next_sibling(timestamp.dup)
      timestamp.remove
    end
  end
end
