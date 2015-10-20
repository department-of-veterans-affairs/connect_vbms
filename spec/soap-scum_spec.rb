require 'spec_helper'
require 'soap-scum'
require 'xmlenc'

describe :SoapScum do
  let (:server_x509_subject) { Nokogiri::XML(fixture('soap-scum/server_x509_subject_keyinfo.xml')) }
  let (:client_x509_subject) { Nokogiri::XML(fixture('soap-scum/client_x509_subject_keyinfo.xml')) }
  let (:server_pc12) { fixture_path('test_keystore_vbms_server_key.p12') }
  let (:client_pc12) { fixture_path('test_keystore_importkey.p12') }
  let (:test_jks_keystore) { fixture_path('test_keystore.jks') }
  let (:test_keystore_pass) { "importkey" }
  let (:keypass) { 'importkey' }

  describe "KeyStore" do
    it "loads a pc12 file and cert" do
      keystore = SoapScum::KeyStore.new
      keystore.add_pc12(server_pc12, keypass)
      server_pkcs12 = OpenSSL::PKCS12.new(File.read(server_pc12), keypass)

      expect(keystore.get_key(server_x509_subject).to_der).to eql(server_pkcs12.key.to_der)
      expect(keystore.get_certificate(server_x509_subject).to_der).to eql(server_pkcs12.certificate.to_der)
    end

    it "returns correct cert and key by subject" do
      keystore = SoapScum::KeyStore.new
      keystore.add_pc12(server_pc12, keypass)
      keystore.add_pc12(client_pc12, keypass)

      server_pkcs12 = OpenSSL::PKCS12.new(File.read(server_pc12), keypass)
      client_pkcs12 = OpenSSL::PKCS12.new(File.read(client_pc12), keypass)

      expect(keystore.get_key(server_x509_subject).to_der).to eql(server_pkcs12.key.to_der)
      expect(keystore.get_certificate(server_x509_subject).to_der).to eql(server_pkcs12.certificate.to_der)

      expect(keystore.get_key(client_x509_subject).to_der).to eql(client_pkcs12.key.to_der)
      expect(keystore.get_certificate(client_x509_subject).to_der).to eql(client_pkcs12.certificate.to_der)
    end
  end

  describe "MessageProcessor" do
    let (:keystore) {
      keystore = SoapScum::KeyStore.new
      keystore.add_pc12(server_pc12, keypass)
      keystore.add_pc12(client_pc12, keypass)
      keystore
    }
    let (:message_processor) {
      SoapScum::MessageProcessor.new(keystore)
    }
    let (:content_document) {
      Nokogiri::XML('<hi-mom xmlns:example="http://example.com"><example:a-doc /></hi-mom>')
    }

    it "Creates basic soap envelope" do
      soap_doc = message_processor.wrap_in_soap(content_document)
      expect(soap_doc.is_a? Nokogiri::XML::Document).to eq(true)
      # TODO(astone)
      # add more expectations to validate the structure of the document
    end

    it "Encrypts and signs a soap message" do
      pending "Fix signing!"
      
      crypto_options = {
        server: {
            certificate: keystore.all.first.certificate,
            keytransport_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::RSA_PKCS1_15,
            cipher_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::AES128
          },
        client: {
            certificate: keystore.all.last.certificate,
            private_key: keystore.all.last.key,
            keytransport_algorithm: "http://www.w3.org/2000/09/xmldsig#sha1",
            cipher_algorithm: "http://www.w3.org/2000/09/xmldsig#rsa-sha1"
          }
        }

      soap_doc = message_processor.wrap_in_soap(content_document)
      encrypted_xml = message_processor.encrypt(soap_doc,
                                                crypto_options,
                                                soap_doc.at_xpath(
                                                  '/soapenv:Envelope/soapenv:Body',
                                                  soapenv: SoapScum::XMLNamespaces::SOAPENV).children)

      

      decrypted_xml = VBMS.decrypt_message_xml(encrypted_xml, test_jks_keystore,
                                               test_keystore_pass, 'test-logfile')

      encrypted_doc = Nokogiri::XML(encrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
      decrypted_doc = Nokogiri::XML(decrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)

      expect(decrypted_doc).to eq(encrypted_doc)
      # TODO(awong): Verify decrypt_xml matches original soap_doc.
    end


    it "can be decrypted with ruby" do
      skip "pending valid encryption and validation with java"
    end
  end

end
