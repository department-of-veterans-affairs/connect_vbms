require 'spec_helper'
require 'soap-scum'

describe :SoapScum do
  describe "KeyStore" do
    let (:server_x509_subject) { Nokogiri::XML(fixture('soap-scum/server_x509_subject_keyinfo.xml')) }
    let (:client_x509_subject) { Nokogiri::XML(fixture('soap-scum/client_x509_subject_keyinfo.xml')) }
    let (:server_pc12) { fixture_path('test_keystore_vbms_server_key.p12') }
    let (:client_pc12) { fixture_path('test_keystore_importkey.p12') }
    let (:keypass) { 'importkey' }

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
end
