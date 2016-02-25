require 'base64'
require 'nokogiri'
require 'xmldsig'

module SoapScum
  module XMLNamespaces
    SOAPENV = 'http://schemas.xmlsoap.org/soap/envelope/'
    WSSE = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
    WSSE11 = 'http://docs.oasis-open.org/wss/oasis-wss-wssecurity-secext-1.1.xsd'
    WSU = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
    DS = 'http://www.w3.org/2000/09/xmldsig#'
    XENC = 'http://www.w3.org/2001/04/xmlenc#'
  end

  class KeyStore
    CertStruct = Struct.new(:certificate, :key)

    def initialize
      @by_subject = {}
    end

    def all
      @by_subject.values
    end

    def add_pc12(path, keypass = '')
      pkcs12 = OpenSSL::PKCS12.new(File.read(path), keypass)
      cert_entry = CertStruct.new(pkcs12.certificate, pkcs12.key)
      @by_subject[x509_to_normalized_subject(pkcs12.certificate)] = cert_entry

      if pkcs12.ca_certs && pkcs12.ca_certs.any?
        issuer_entry = CertStruct.new(pkcs12.ca_certs.first)
        @by_subject[x509_to_normalized_subject(pkcs12.ca_certs.first)] = issuer_entry
      end
    end

    def add_cert(path, _keypass = '')
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
    # TODO(awong): Do not expose the internal cipher object. This object has
    # mutable state which breaks the data hiding of this object. Return a
    # clone or just keep the cipher completely hidden.
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
                                'xmlns:cdm' => 'http://vbms.vba.va.gov/cdm',
                                'xmlns:doc' => 'http://vbms.vba.va.gov/cdm/document/v4',
                                'xmlns:v4' => 'http://vbms.vba.va.gov/external/eDocumentService/v4',
                                'xmlns:xop' => 'http://www.w3.org/2004/08/xop/include') do
          xml['soapenv'].Body('wsu:Id' => soap_body_id, 'xmlns:wsu' => XMLNamespaces::WSU) do
            xml.REPLACEME unless contents_doc.nil?
          end
        end
      end

      # This bit of terrible code (and the REPLACEME node above) are
      # here because Nokogiri has a longstanding bug where it will
      # forcibly reassign elements without explicit namespaces to be
      # in the parent namespace, so adding a node like <ListDocuments>
      # will be changed to <soapenv:ListDocuments>. So, to do this
      # instead, we have to make the XML tree, output it to a string,
      # replace the REPLACEME node with the child tree string and
      # reparse. Ugh, Nokogiri. Why?
      # See https://github.com/sparklemotion/nokogiri/issues/425 for
      # more details on the Nokogiri bug
      if contents_doc.nil?
        builder.doc
      else
        if body_node(contents_doc)
          # compatibilty with current Request
          inner_str = body_node(contents_doc).children.map { |c| serialize_xml_strictly(c, false) }.join('')
        else
          inner_str = serialize_xml_strictly(contents_doc.root, false)
        end

        xml_str = serialize_xml_strictly(builder.doc)
        xml_str.gsub!('<soapenv:REPLACEME/>', inner_str)
        parse_xml_strictly(xml_str)
      end
    end

    def encrypt(soap_doc, _request_name, crypto_options, nodes_to_encrypt, validity: 5.minutes)
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
      # signed_doc.root.serialize(save_with: 0)
      signed_doc.root.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
    end

    def decrypt(soap_doc, keyfile, keypass)
      decipher = get_block_cipher(soap_doc.at_xpath(
        '//soapenv:Body/xenc:EncryptedData/xenc:EncryptionMethod',
        VBMS::XML_NAMESPACES)['Algorithm'])

      key_cipher_text = Base64.decode64(soap_doc.at_xpath(
        '//xenc:EncryptedKey/xenc:CipherData/xenc:CipherValue',
        VBMS::XML_NAMESPACES).text)
      symmetric_key = decrypted_symmetric_key(key_cipher_text, keyfile, keypass)

      cipher_text = Base64.decode64(soap_doc.at_xpath('//soapenv:Body/xenc:EncryptedData/xenc:CipherData/xenc:CipherValue', VBMS::XML_NAMESPACES).text)
      known_iv = cipher_text[0..(decipher.key_len - 1)]

      plain = decrypt_cipher_text(decipher, symmetric_key, known_iv, cipher_text)
  
      body_node(soap_doc).children.each(&:remove) # destroy children elephants
      Nokogiri::XML::Builder.with(body_node(soap_doc)) do |xml|
        xml << plain
      end
      soap_doc
    end

    def xenc_decrypt(xml, keyfile, keypass)
      # encrypted_doc = Xmlenc::EncryptedDocument.new(serialize_xml_strictly(soap_doc))
      encrypted_doc = Xmlenc::EncryptedDocument.new(xml)
      # TODO(awong): Associate a keystore class with this API instead of
      # passing path per request. The keystore client should take in a ds:KeyInfo
      # node and know how to find the associated private key.
      
      encryption_key = OpenSSL::PKCS12.new(File.read(keyfile), keypass)
      decrypted_doc = encrypted_doc.decrypt(encryption_key.key)

      # TODO(awong): Signature verification.
      # TODO(awong): Timestamp validation.

      # parse_xml_strictly decrypted_doc
      # Nokogiri::XML decrypted_doc
      decrypted_doc
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

    def decrypt_cipher_text(decipher, key, iv, cipher_text)
      decipher.decrypt
      decipher.key = key
      decipher.iv = iv
      # Manually handle the xmlenc padding which is not supported by openssl.
      # See http://openssl.6102.n7.nabble.com/ISO10126-padding-in-openssl-td9228.html
      # for details.
      decipher.padding = 0

      plain = decipher.update(cipher_text)
      plain << decipher.final
      iv = plain.byteslice(0, decipher.block_size)
      plain = plain.byteslice(decipher.block_size, plain.length)
      plain = remove_xmlenc_padding(decipher.block_size, plain)
    end

    def parse_xml_strictly(xml)
      Nokogiri::XML(xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    end

    def serialize_xml_strictly(xmldoc, preamble = true)
      options = Nokogiri::XML::Node::SaveOptions::AS_XML
      options |= Nokogiri::XML::Node::SaveOptions::NO_DECLARATION unless preamble

      xmldoc.serialize(
        encoding: 'UTF-8',
        save_with: options
      )
    end

    def add_xmlenc_padding(block_size, unpadded_string)
      # Add xmlenc padding as specified in the xmlenc spec.
      # http://www.w3.org/TR/2002/REC-xmlenc-core-20021210/Overview.html#sec-Alg-Block
      fail "block size #{block_size} must be > 0." if block_size <= 0
      padding_length = (block_size - unpadded_string.length % block_size)
      num_rand_bytes = padding_length - 1
      unpadded_string << SecureRandom.random_bytes(num_rand_bytes) if num_rand_bytes > 0
      unpadded_string << padding_length.chr  # TODO(awong): Do we encoding issues?
      unpadded_string  # String is now padded.
    end

    def remove_xmlenc_padding(block_size, padded_string)
      # Remove xmlenc padding as specified in the xmlenc spec.
      # http://www.w3.org/TR/2002/REC-xmlenc-core-20021210/Overview.html#sec-Alg-Block
      fail 'padded_string must be greater than 0 bytes.' if padded_string.empty?
      padding_length = padded_string.bytes[-1]
      fail "Padding length #{padding_length} larger than full plaintext." if 
                                              padding_length > padded_string.size
      fail "Padding length #{padding_length} violates xmlsec sanity checks for " \
            "block size #{block_size}." unless padding_length >= 1 && 
                                              padding_length <= block_size &&
                                              (padded_string.size - padding_length - block_size) > 0

      # TODO astone: determine if any more checks need to be done here.
      # start of string: padded_string.size - padding_length - block_size
      padded_string.byteslice(0, padded_string.size - padding_length)
    end

    def body_node(doc)
      doc.at_xpath('/soapenv:Envelope/soapenv:Body',
                   soapenv: XMLNamespaces::SOAPENV,
                   'xmlns:cdm' => 'http://vbms.vba.va.gov/cdm',
                   'xmlns:doc' => 'http://vbms.vba.va.gov/cdm/document/v4',
                   'xmlns:v4' => 'http://vbms.vba.va.gov/external/eDocumentService/v4',
                   'xmlns:xop' => 'http://www.w3.org/2004/08/xop/include')
    end

    private

    def sign_soap_doc(soap_doc, private_key)
      signed_doc = Xmldsig::SignedDocument.new(soap_doc)
      signed_doc.sign(private_key)
      signed_doc
    end

    def decrypted_symmetric_key(key_cipher_text, keyfile, keypass)
      server_p12 = OpenSSL::PKCS12.new(File.read(keyfile), keypass)
      server_p12.key.private_decrypt(key_cipher_text)
    end

    def timestamp_node(soap_doc)
      soap_doc.at_xpath(
        '/soapenv:Envelope/soapenv:Header/wsse:Security/wsu:Timestamp',
        soapenv: SoapScum::XMLNamespaces::SOAPENV,
        'xmlns:wsse' => XMLNamespaces::WSSE,
        'xmlns:wsu' => XMLNamespaces::WSU)
    end

    def generate_id
      SecureRandom.hex(5)
    end

    def timestamp_id
      @timestamp_id ||= "TS-#{generate_id}"
    end

    def soap_body_id
      @soap_body_id ||= "id-#{generate_id}"
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

    def encrypted_key_id
      @encrypted_key_id ||= "EK-#{generate_id}"
    end

    def encrypted_data_id
      @encrypted_data_id ||= "ED-#{generate_id}"
    end

    def generate_symmetric_key(key_len)
      SecureRandom.random_bytes(key_len)
    end

    def get_random_iv
      SecureRandom.random_bytes(cipher.key_len)
    end

    # Takes an XMLBuilder and adds the XML Encryption template.
    def add_xmlenc_template(xml, certificate, keytransport_algorithm, cipher_algorithm)
      # #5.4.1 Lists the valid ciphers and block sizes.
      # TODO(astone): improve this
      self.key_id = encrypted_key_id
      self.cipher_algorithm = cipher_algorithm
      self.cipher = get_block_cipher(cipher_algorithm)    # instantiate a new Cipher
      self.iv = get_random_iv
      self.symmetric_key = generate_symmetric_key(cipher.key_len)

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
          encrypted_node_id = encrypted_data_id
          encrypted_node = generate_encrypted_data(node, encrypted_node_id, key_id, symmetric_key, cipher_algorithm)
          node.children.each(&:remove) # remove unencrypted node
          node << encrypted_node
          xml['xenc'].DataReference(URI: "##{encrypted_node_id}")
        end
      end
    end

    def generate_encrypted_data(node, encrypted_node_id, key_id, symmetric_key, cipher_algorithm)
      # raw_xml = node.children.collect(&:serialize).join
      raw_xml = node.children.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)

      cipher.encrypt
      cipher.padding = 0
      cipher.iv = iv
      cipher.key = symmetric_key
      cipher_text = iv + cipher.update(
        add_xmlenc_padding(cipher.block_size, raw_xml)) + cipher.final

      # builder portion
      builder = Nokogiri::XML::Builder.new do |xml|
        xml['xenc'].EncryptedData('xmlns:xenc' => 'http://www.w3.org/2001/04/xmlenc#', Id: encrypted_node_id, Type: 'http://www.w3.org/2001/04/xmlenc#Content') do
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
      xml['ds'].Signature('xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#', Id: signature_id) do
        xml['ds'].SignedInfo('xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#',
                             'xmlns:soapenv' => XMLNamespaces::SOAPENV
                            ) do
          # TODO(awong): Allow modification of CanonicalizationMethod.
          xml['ds'].CanonicalizationMethod(Algorithm: 'http://www.w3.org/2001/10/xml-exc-c14n#') do
            xml['ec'].InclusiveNamespaces('xmlns:ec' => 'http://www.w3.org/2001/10/xml-exc-c14n#',
                                          'PrefixList' => 'cdm doc soapenv v4 xop')
          end
          xml['ds'].SignatureMethod(Algorithm: signature_method)
          nodes_to_sign.each do |node|
            xml['ds'].Reference(URI: "##{node.attr('wsu:Id')}") do
              xml['ds'].Transforms do
                xml['ds'].Transform(Algorithm: 'http://www.w3.org/2001/10/xml-exc-c14n#') do
                  prefix_list = (node.name == 'Body' ? 'cdm doc v4 xop' : 'wsse cdm doc soapenv v4 xop')
                  xml['ec'].InclusiveNamespaces('xmlns:ec' => 'http://www.w3.org/2001/10/xml-exc-c14n#', PrefixList: prefix_list)
                end
              end
              xml['ds'].DigestMethod(Algorithm: digest_method)
              xml['ds'].DigestValue
            end
          end
        end
        xml['ds'].SignatureValue
        ki_id = key_info_id
        xml['ds'].KeyInfo('xmlns:ds' => XMLNamespaces::DS, Id: ki_id) do
          str_id = security_token_id
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
        header_builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['soapenv'].Header('xmlns:soapenv' => XMLNamespaces::SOAPENV)
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
