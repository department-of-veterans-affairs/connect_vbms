require 'spec_helper'
require 'soap-scum'
require 'xmlenc'
require 'timecop'

describe :SoapScum do
  let (:server_x509_subject) { Nokogiri::XML(fixture('soap-scum/server_x509_subject_keyinfo.xml')) }
  let (:client_x509_subject) { Nokogiri::XML(fixture('soap-scum/client_x509_subject_keyinfo.xml')) }
  # let (:server_pc12) { fixture_path('test_keystore_vbms_server_key.p12') }
  let (:client_pc12) { fixture_path('test_keystore_importkey.p12') }
  let (:server_cert) { fixture_path('server.crt') }

  let (:test_jks_keystore) { fixture_path('test_keystore.jks') }
  let (:test_keystore_pass) { 'importkey' }
  let (:keypass) { 'importkey' }

  describe 'KeyStore' do
    it 'loads a pc12 file and cert' do
      keystore = SoapScum::KeyStore.new
      # keystore.add_pc12(server_pc12, keypass)
      skip
      # server_pkcs12 = OpenSSL::PKCS12.new(File.read(server_pc12), keypass)

      # expect(keystore.get_key(server_x509_subject).to_der).to eql(server_pkcs12.key.to_der)
      expect(keystore.get_certificate(server_x509_subject).to_der).to eql(server_pkcs12.certificate.to_der)
    end

    it 'returns correct cert and key by subject' do
      keystore = SoapScum::KeyStore.new
      # keystore.add_pc12(server_pc12, keypass)
      keystore.add_pc12(client_pc12, keypass)
      keystore.add_cert(server_cert)

      # server_pkcs12 = OpenSSL::PKCS12.new(File.read(server_pc12), keypass)
      client_pkcs12 = OpenSSL::PKCS12.new(File.read(client_pc12), keypass)

      # expect(keystore.get_key(server_x509_subject).to_der).to eql(server_pkcs12.key.to_der)
      # expect(keystore.get_certificate(server_x509_subject).to_der).to eql(server_pkcs12.certificate.to_der)

      expect(keystore.get_key(client_x509_subject).to_der).to eql(client_pkcs12.key.to_der)
      expect(keystore.get_certificate(client_x509_subject).to_der).to eql(client_pkcs12.certificate.to_der)
    end

    it 'loads a PEM encoded public certificate' do
      keystore = SoapScum::KeyStore.new
      keystore.add_cert(server_cert)

      cert = OpenSSL::X509::Certificate.new(File.read(server_cert))

      expect(keystore.get_certificate(server_x509_subject).to_der).to eql(cert.to_der)
    end
  end

  describe 'MessageProcessor' do
    let (:keystore) do
      keystore = SoapScum::KeyStore.new
      keystore.add_pc12(client_pc12, keypass)
      keystore.add_cert(server_cert)
      keystore
    end
    let (:crypto_options) do
      {
        server: {
          certificate: keystore.all.last.certificate,
          keytransport_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::RSA_PKCS1_15,
          cipher_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::AES128
        },
        client: {
          certificate: keystore.all.first.certificate,
          private_key: keystore.all.first.key,
          digest_algorithm: 'http://www.w3.org/2000/09/xmldsig#sha1',
          signature_algorithm: 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
        }
      }
    end
    let (:message_processor) do
      SoapScum::MessageProcessor.new(keystore)
    end
    let (:content_document) do
      Nokogiri::XML('<hi-mom xmlns:example="http://example.com"><example:a-doc /></hi-mom>')
    end

    describe '#wrap_in_soap' do
      it 'creates a valid SOAP document' do
        soap_doc = message_processor.wrap_in_soap(content_document)
        xsd = Nokogiri::XML::Schema(fixture('soap.xsd'))
        expect(xsd.validate(soap_doc).size).to eq(0)
      end
    end

    describe '#encrypt' do
      it 'returns valid SOAP' do
        soap_doc = message_processor.wrap_in_soap(content_document)
        ruby_encrypted_xml = message_processor.encrypt(soap_doc,
                                                       'listDocuments',
                                                       crypto_options,
                                                       soap_doc.at_xpath(
                                                         '/soapenv:Envelope/soapenv:Body',
                                                         soapenv: SoapScum::XMLNamespaces::SOAPENV).children)

        xsd = Nokogiri::XML::Schema(fixture('soap.xsd'))
        doc = Nokogiri::XML(ruby_encrypted_xml)

        expect(xsd.validate(doc).size).to eq(0)
      end

      it 'creates an encrypted soap doc' do
        soap_doc = message_processor.wrap_in_soap(content_document)
        ruby_encrypted_xml = message_processor.encrypt(soap_doc,
                                                       'listDocuments',
                                                       crypto_options,
                                                       soap_doc.at_xpath(
                                                         '/soapenv:Envelope/soapenv:Body',
                                                         soapenv: SoapScum::XMLNamespaces::SOAPENV).children)

        xsd = Nokogiri::XML::Schema(fixture('soap.xsd'))
        doc = Nokogiri::XML(ruby_encrypted_xml)

        expect(xsd.validate(doc).size).to eq(0)
        # TODO(awong): Verify decrypt_xml matches original soap_doc.
      end

      def parsed_timestamp(xml)
        x = xml.at_xpath('//wsu:Timestamp', VBMS::XML_NAMESPACES)
        
        {
          created: x.at_xpath('//wsu:Created', VBMS::XML_NAMESPACES).text,
          expires: x.at_xpath('//wsu:Expires', VBMS::XML_NAMESPACES).text
        }
      end

      it 'encrypts the same as java' do
        soap_doc = message_processor.wrap_in_soap(content_document)

        java_encrypted_xml = VBMS.encrypted_soap_document_xml(soap_doc,
                                                              test_jks_keystore,
                                                              test_keystore_pass,
                                                              'listDocuments')
        parsed_java_xml = Nokogiri::XML(java_encrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
        java_timestamp = parsed_timestamp(parsed_java_xml)

        time = Time.parse(java_timestamp[:created])
        ruby_encrypted_xml = nil
          
        Timecop.freeze(time) do
          ruby_encrypted_xml = message_processor.encrypt(soap_doc,
                                                         'listDocuments',
                                                         crypto_options,
                                                         soap_doc.at_xpath(
                                                           '/soapenv:Envelope/soapenv:Body',
                                                           soapenv: SoapScum::XMLNamespaces::SOAPENV).children)
        end
          
        parsed_ruby_xml = Nokogiri::XML(ruby_encrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)

        # expect some fields to be the same
        ruby_timestamp = parsed_timestamp(parsed_ruby_xml)
        
        expect(ruby_timestamp[:created]).to eq(java_timestamp[:created])
        expect(ruby_timestamp[:expires]).to eq(java_timestamp[:expires])
      end

      it 'can be decrypted with ruby' do
        skip 'pending valid encryption and validation with java'
      end
    end
  end
end
