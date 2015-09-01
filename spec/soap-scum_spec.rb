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
      # TODO(awong): Verify structure.
    end

    it "Encrypts and signs a soap message" do
      soap_doc = message_processor.wrap_in_soap(content_document)
      encrypted_doc = message_processor.encrypt(soap_doc, keystore.all.first.certificate,
                                                keystore.all.first.key,
                                                SoapScum::MessageProcessor::CryptoAlgorithms::RSA1_5,
                                                SoapScum::MessageProcessor::CryptoAlgorithms::AES128,
                                                soap_doc.at_xpath('/soapenv:Envelope/soapenv:Body',
                                                                  soapenv: SoapScum::XMLNamespaces::SOAPENV).children)
      encrypted_xml = encrypted_doc.serialize(encoding: 'UTF-8', save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      decrypted_xml = VBMS.decrypt_message_xml(encrypted_xml, test_jks_keystore,
                                               test_keystore_pass, 'test-logfile')
      # TODO(awong): Verify decrypt_xml matches original soap_doc.
    end
  end

end
