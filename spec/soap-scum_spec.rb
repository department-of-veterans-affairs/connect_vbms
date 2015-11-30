require 'spec_helper'
require 'soap-scum'
require 'xmlenc'
require 'timecop'

describe :SoapScum do
  before(:all) do
    @server_x509_subject = Nokogiri::XML(fixture('soap-scum/server_x509_subject_keyinfo.xml'))
    @client_x509_subject = Nokogiri::XML(fixture('soap-scum/client_x509_subject_keyinfo.xml'))
    # let (:server_pc12) { fixture_path('test_keystore_vbms_server_key.p12') }
    @client_pc12 = fixture_path('test_keystore_importkey.p12')
    @server_cert = fixture_path('server.crt')
    @test_jks_keystore = fixture_path('test_keystore.jks') 
    @test_keystore_pass = 'importkey'
    @keypass = 'importkey'
  end
                         
  describe 'KeyStore' do
    it 'loads a pc12 file and cert' do
      keystore = SoapScum::KeyStore.new
      # keystore.add_pc12(server_pc12, keypass)
      skip
      # server_pkcs12 = OpenSSL::PKCS12.new(File.read(server_pc12), keypass)

      # expect(keystore.get_key(server_x509_subject).to_der).to eql(server_pkcs12.key.to_der)
      expect(keystore.get_certificate(@server_x509_subject).to_der).to eql(@server_pkcs12.certificate.to_der)
    end

    it 'returns correct cert and key by subject' do
      keystore = SoapScum::KeyStore.new
      # keystore.add_pc12(server_pc12, keypass)
      keystore.add_pc12(@client_pc12, @keypass)
      keystore.add_cert(@server_cert)

      # server_pkcs12 = OpenSSL::PKCS12.new(File.read(server_pc12), keypass)
      client_pkcs12 = OpenSSL::PKCS12.new(File.read(@client_pc12), @keypass)

      # expect(keystore.get_key(server_x509_subject).to_der).to eql(server_pkcs12.key.to_der)
      # expect(keystore.get_certificate(server_x509_subject).to_der).to eql(server_pkcs12.certificate.to_der)

      expect(keystore.get_key(@client_x509_subject).to_der).to eql(client_pkcs12.key.to_der)
      expect(keystore.get_certificate(@client_x509_subject).to_der).to eql(client_pkcs12.certificate.to_der)
    end

    it 'loads a PEM encoded public certificate' do
      keystore = SoapScum::KeyStore.new
      keystore.add_cert(@server_cert)

      cert = OpenSSL::X509::Certificate.new(File.read(@server_cert))

      expect(keystore.get_certificate(@server_x509_subject).to_der).to eql(cert.to_der)
    end
  end

  describe 'MessageProcessor' do
    # These should be lets in normal circumstances, but I want to make
    # tests go faster and do a before(:all) instead
    before(:all) do
      @keystore = SoapScum::KeyStore.new
      @keystore.add_pc12(@client_pc12, @keypass)
      @keystore.add_cert(@server_cert)

      @crypto_options = {
        server: {
          certificate: @keystore.all.last.certificate,
          keytransport_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::RSA_PKCS1_15,
          cipher_algorithm: SoapScum::MessageProcessor::CryptoAlgorithms::AES128
        },
        client: {
          certificate: @keystore.all.first.certificate,
          private_key: @keystore.all.first.key,
          digest_algorithm: 'http://www.w3.org/2000/09/xmldsig#sha1',
          signature_algorithm: 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
        }
      }
    
      @message_processor = SoapScum::MessageProcessor.new(@keystore)
      @content_document = Nokogiri::XML('<hi-mom xmlns:example="http://example.com"><example:a-doc /></hi-mom>')

      @soap_document = @message_processor.wrap_in_soap(@content_document)
    
      @java_encrypted_xml = VBMS.encrypted_soap_document_xml(@soap_document,
                                                             @test_jks_keystore,
                                                             @test_keystore_pass,
                                                             'listDocuments')
    
      @parsed_java_xml =  Nokogiri::XML(@java_encrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    end
    
    describe '#wrap_in_soap' do
      it 'creates a valid SOAP document' do
        xsd = Nokogiri::XML::Schema(fixture('soap.xsd'))
        expect(xsd.validate(@soap_document).size).to eq(0)
      end
    end

    describe '#encrypt' do
      it 'returns valid SOAP' do
        ruby_encrypted_xml = @message_processor.encrypt(@soap_document,
                                                        'listDocuments',
                                                        @crypto_options,
                                                        @soap_document.at_xpath(
                                                          '/soapenv:Envelope/soapenv:Body',
                                                          soapenv: SoapScum::XMLNamespaces::SOAPENV).children)

        xsd = Nokogiri::XML::Schema(fixture('soap.xsd'))
        doc = Nokogiri::XML(ruby_encrypted_xml)

        expect(xsd.validate(doc).size).to eq(0)
      end

      context "compared to the Java version" do

        def parsed_timestamp(xml)
          x = xml.at_xpath('//wsu:Timestamp', VBMS::XML_NAMESPACES)

          {
            id: x['wsu:Id'],
            created: x.at_xpath('//wsu:Created', VBMS::XML_NAMESPACES).text,
            expires: x.at_xpath('//wsu:Expires', VBMS::XML_NAMESPACES).text
          }
        end

        it 'should encrypt in a similar way to the Java version' do
          raise @soap_document.to_xml.to_s
          @java_timestamp = parsed_timestamp(@parsed_java_xml)
          time = Time.parse(@java_timestamp[:created])

          body_id = @parsed_java_xml.at_xpath("//soapenv:Body", VBMS::XML_NAMESPACES)['wsu:Id']
          
          # This forces the Ruby encryption to be at the exact same
          # time as the Java encryption. You can't just wrap both in a
          # single Timecop declaration because Java code exists
          # outside of mocking reach
          Timecop.freeze(time) do
            # mock the Ruby to return the same IDs as the Java
            allow(@message_processor).to receive(:timestamp_id).and_return(@java_timestamp[:id])
            allow(@message_processor).to receive(:soap_body_id).and_return(body_id)
            
            @ruby_encrypted_xml = @message_processor.encrypt(@soap_document,
                                                             'listDocuments',
                                                             @crypto_options,
                                                             @soap_document.at_xpath(
                                                               '/soapenv:Envelope/soapenv:Body',
                                                               soapenv: SoapScum::XMLNamespaces::SOAPENV).children)
            
            @parsed_ruby_xml = Nokogiri::XML(@ruby_encrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
          end

          # expect some timestamp fields to be the same
          ruby_timestamp = parsed_timestamp(@parsed_ruby_xml)

          expect(ruby_timestamp[:id]).to eq(@java_timestamp[:id])
          expect(ruby_timestamp[:created]).to eq(@java_timestamp[:created])
          expect(ruby_timestamp[:expires]).to eq(@java_timestamp[:expires])            

          # Check the signed info for the timestamp
          ruby_signed_info = @parsed_ruby_xml.at_xpath("//ds:Reference[@URI='##{ruby_timestamp[:id]}']", ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(ruby_signed_info).to_not be_nil
          java_signed_info = @parsed_java_xml.at_xpath("//ds:Reference[@URI='##{ruby_timestamp[:id]}']", ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(java_signed_info).to_not be_nil
          expect(ruby_signed_info.to_xml).to eq(java_signed_info.to_xml)

          # check the signed info for the encrypted part
          ruby_signed_info = @parsed_ruby_xml.at_xpath("//ds:Reference[@URI='##{body_id}']", ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(ruby_signed_info).to_not be_nil
          java_signed_info = @parsed_java_xml.at_xpath("//ds:Reference[@URI='##{body_id}']", ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(java_signed_info).to_not be_nil
          expect(ruby_signed_info.to_xml).to eq(java_signed_info.to_xml)
        end
      end
      
      it 'can be decrypted with ruby' do
        skip 'pending valid encryption and validation with java'
      end
    end
  end
end
