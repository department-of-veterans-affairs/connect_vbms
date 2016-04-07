# require 'spec_helper'
# require 'soap-scum'
# require 'xmlenc'
require 'timecop'

describe VBMS::SoapScum do
  before(:all) do
    @server_x509_subject = Nokogiri::XML(fixture('soap-scum/server_x509_subject_keyinfo.xml'))
    @client_x509_subject = Nokogiri::XML(fixture('soap-scum/client_x509_subject_keyinfo.xml'))
    @client_pc12 = fixture_path('test_keystore_importkey.p12')
    @server_cert = fixture_path('test_server.crt')
    @server_p12_key = fixture_path('test_keystore_vbms_server_key.p12')
    @server_key = fixture_path('test_server_key.key')
    @test_jks_keystore = fixture_path('test_keystore.jks')
    @test_keystore_pass = 'importkey'
    @keypass = 'importkey'
  end

  describe 'KeyStore' do
    it 'returns correct cert and key by subject' do
      keystore = VBMS::SoapScum::KeyStore.new
      keystore.add_pc12(@client_pc12, @keypass)
      keystore.add_cert(@server_cert)

      client_pkcs12 = OpenSSL::PKCS12.new(File.read(@client_pc12), @keypass)

      expect(keystore.get_key(@client_x509_subject).to_der).to eql(client_pkcs12.key.to_der)
      expect(keystore.get_certificate(@client_x509_subject).to_der).to eql(client_pkcs12.certificate.to_der)
    end

    it 'loads a PEM encoded public certificate' do
      keystore = VBMS::SoapScum::KeyStore.new
      keystore.add_cert(@server_cert)

      cert = OpenSSL::X509::Certificate.new(File.read(@server_cert))
      expect(keystore.get_certificate(@server_x509_subject).to_der).to eql(cert.to_der)
    end
  end

  describe 'MessageProcessor' do
    # These should be lets in normal circumstances, but I want to make
    # tests go faster and do a before(:all) instead
    before do
      @keystore = VBMS::SoapScum::KeyStore.new
      @keystore.add_pc12(@client_pc12, @keypass)
      @keystore.add_cert(@server_cert)

      @crypto_options = {
        server: {
          certificate: @keystore.all.last.certificate,
          keytransport_algorithm: VBMS::SoapScum::MessageProcessor::CryptoAlgorithms::RSA_PKCS1_15,
          cipher_algorithm: VBMS::SoapScum::MessageProcessor::CryptoAlgorithms::AES128
        },
        client: {
          certificate: @keystore.all.first.certificate,
          private_key: @keystore.all.first.key,
          digest_algorithm: 'http://www.w3.org/2000/09/xmldsig#sha1',
          signature_algorithm: 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
        }
      }

      @message_processor = VBMS::SoapScum::MessageProcessor.new(@keystore)
    end

    describe '#wrap_in_soap' do
      # before do

      # end
      let(:content_document) { Nokogiri::XML('<hi-mom xmlns:example="http://example.com"><example:a-doc/><b-doc/></hi-mom>') }
      let(:soap_document) { @message_processor.wrap_in_soap(content_document) }
      let(:java_encrypted_xml) do
        VBMS.encrypted_soap_document_xml(soap_document,
                                         @test_jks_keystore,
                                         @test_keystore_pass,
                                         'listDocuments')
      end
      let(:parsed_java_xml) { Nokogiri::XML(java_encrypted_xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT, &:noblanks) }
      
      it 'creates a valid SOAP document' do
        xsd = Nokogiri::XML::Schema(fixture('soap.xsd'))
        expect(xsd.validate(soap_document).size).to eq(0)
      end

      it 'should not reassign a namespace if the parent has no namespaces' do
        expect(soap_document.at_xpath('//hi-mom')).to_not be_nil
        expect(soap_document.at_xpath('//hi-mom/e:a-doc', e: 'http://example.com')).to_not be_nil
        expect(soap_document.at_xpath('//hi-mom/b-doc')).to_not be_nil
      end

      it 'should not reassign a namespace if the root has a namespace' do
        cd = Nokogiri::XML('<example:hi-mom xmlns:example="http://example.com"><example:a-doc/><b-doc/></hi-mom>')
        soap_document = @message_processor.wrap_in_soap(cd)
        expect(soap_document.at_xpath('//e:hi-mom', e: 'http://example.com')).to_not be_nil
        expect(soap_document.at_xpath('//e:hi-mom/e:a-doc', e: 'http://example.com')).to_not be_nil
        expect(soap_document.at_xpath('//e:hi-mom/b-doc', e: 'http://example.com')).to_not be_nil
      end
    end

    describe '#encrypt' do
      let(:content_document) do 
        Nokogiri::XML("<v4:listDocuments>\n
        <v4:fileNumber>784449089</v4:fileNumber>\n
        </v4:listDocuments>")
      end
      let(:soap_document) { @message_processor.wrap_in_soap(content_document) }
      let(:java_encrypted_xml) do
        VBMS.encrypted_soap_document_xml(soap_document,
                                         @test_jks_keystore,
                                         @test_keystore_pass,
                                         'listDocuments')
      end
      let(:parsed_java_xml) do 
        Nokogiri::XML(java_encrypted_xml,
                      nil,
                      nil,
                      Nokogiri::XML::ParseOptions::STRICT,
                      &:noblanks) 
      end

      it 'returns valid SOAP' do
        ruby_encrypted_xml = @message_processor.encrypt(
          soap_document,
          'listDocuments',
          @crypto_options,
          soap_document.at_xpath(
            '/soapenv:Envelope/soapenv:Body',
            soapenv: VBMS::SoapScum::XMLNamespaces::SOAPENV).children)

        xsd = Nokogiri::XML::Schema(fixture('soap.xsd'))
        doc = Nokogiri::XML(ruby_encrypted_xml)

        expect(xsd.validate(doc).size).to eq(0)
      end

      context 'compared to the Java version' do
        # Expected behavior: Ruby's #encrypt method can create a SOAP request which
        # matches that of the Java version.
        # This is a beast spec which can be broken up
        it 'should encrypt similarly' do
          @java_timestamp = parsed_timestamp(parsed_java_xml)
          time = Time.parse(@java_timestamp[:created])

          body_id = parsed_java_xml.at_xpath('//soapenv:Body', VBMS::XML_NAMESPACES)['wsu:Id']
          signature_id = parsed_java_xml.at_xpath('//ds:Signature', VBMS::XML_NAMESPACES)['Id']
          key_info_id = parsed_java_xml.at_xpath('//ds:Signature/ds:KeyInfo',
                                                 VBMS::XML_NAMESPACES)['Id']
          str_id = parsed_java_xml.at_xpath(
            '//ds:Signature/ds:KeyInfo/wsse:SecurityTokenReference',
            VBMS::XML_NAMESPACES)['wsu:Id']
          ek_id = parsed_java_xml.at_xpath('//xenc:EncryptedKey',
                                           VBMS::XML_NAMESPACES)['Id']
          ed_id = parsed_java_xml.at_xpath('//xenc:EncryptedData',
                                           VBMS::XML_NAMESPACES)['Id']

          algorithm = parsed_java_xml.at_xpath('//soapenv:Body/xenc:EncryptedData/xenc:EncryptionMethod', VBMS::XML_NAMESPACES)['Algorithm']
          decipher = @message_processor.get_block_cipher(algorithm)

          key_cipher_text = Base64.decode64(parsed_java_xml.at_xpath('//xenc:EncryptedKey/xenc:CipherData/xenc:CipherValue', VBMS::XML_NAMESPACES).text)
          symmetric_key = decrypted_symmetric_key(key_cipher_text)

          cipher_text = Base64.decode64(parsed_java_xml.at_xpath('//soapenv:Body/xenc:EncryptedData/xenc:CipherData/xenc:CipherValue', VBMS::XML_NAMESPACES).text)
          known_iv = cipher_text[0..(decipher.key_len - 1)]

          # This forces the Ruby encryption to be at the exact same
          # time as the Java encryption. You can't just wrap both in a
          # single Timecop declaration because Java code exists
          # outside of the reach of any mocks
          Timecop.freeze(time) do
            # mock the Ruby to return the same IDs as the Java
            allow(@message_processor).to receive(:timestamp_id).and_return(@java_timestamp[:id])
            allow(@message_processor).to receive(:soap_body_id).and_return(body_id)
            allow(@message_processor).to receive(:signature_id).and_return(signature_id)
            allow(@message_processor).to receive(:key_info_id).and_return(key_info_id)
            allow(@message_processor).to receive(:security_token_id).and_return(str_id)
            allow(@message_processor).to receive(:encrypted_key_id).and_return(ek_id)
            allow(@message_processor).to receive(:encrypted_data_id).and_return(ed_id)
            allow(@message_processor).to receive(:generate_symmetric_key).and_return(symmetric_key)
            allow(@message_processor).to receive(:get_random_iv).and_return(known_iv)

            @ruby_encrypted_xml = @message_processor.encrypt(soap_document,
                                                             'listDocuments',
                                                             @crypto_options,
                                                             soap_document.at_xpath(
                                                               '/soapenv:Envelope/soapenv:Body',
                                                               soapenv: VBMS::SoapScum::XMLNamespaces::SOAPENV).children)

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
          java_signed_info = parsed_java_xml.at_xpath("//ds:Reference[@URI='##{ruby_timestamp[:id]}']", ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(java_signed_info).to_not be_nil

          # check the signed info for the encrypted part
          ruby_signed_info = @parsed_ruby_xml.at_xpath("//ds:Reference[@URI='##{body_id}']", ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(ruby_signed_info).to_not be_nil
          java_signed_info = parsed_java_xml.at_xpath("//ds:Reference[@URI='##{body_id}']", ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(java_signed_info).to_not be_nil

          ruby_signature = @parsed_ruby_xml.at_xpath('//ds:Signature', ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(ruby_signature).to_not be_nil
          java_signature = parsed_java_xml.at_xpath('//ds:Signature', ds: 'http://www.w3.org/2000/09/xmldsig#')
          expect(java_signature).to_not be_nil

          # FAILS on validation when decrypted with xenc_decrypt
          # ruby_decrypted_doc = @message_processor.xenc_decrypt(@ruby_encrypted_xml, @server_p12_key, @keypass)
          ruby_decrypted_doc = @message_processor.decrypt(@parsed_ruby_xml, @server_p12_key, @keypass)
          ruby_signed_document = Xmldsig::SignedDocument.new(ruby_decrypted_doc)

          expect(ruby_signed_document.validate(@crypto_options[:client][:certificate])).to be_truthy

          # FAILS validation
          # java_decrypted_doc = @message_processor.xenc_decrypt(java_encrypted_xml, @server_p12_key, @keypass)
          # java_signed_document = Xmldsig::SignedDocument.new(java_decrypted_doc)
          # expect(java_signed_document.validate(@crypto_options[:client][:certificate])).to be_truthy

          # FAILS validation
          java_decrypted_doc = @message_processor.decrypt(parsed_java_xml, @server_p12_key, @keypass)
          java_signed_document = Xmldsig::SignedDocument.new(java_decrypted_doc)

          expect(java_signed_document.validate(@crypto_options[:client][:certificate])).to be_truthy
        end
      end

      it 'can be decrypted with ruby' do
        java_decrypted_xml = @message_processor.xenc_decrypt(java_encrypted_xml, @server_p12_key, @keypass)
        java_decrypted_doc = Nokogiri::XML(java_decrypted_xml)
        java_decrypted_body = java_decrypted_doc.at_xpath('//soapenv:Body', VBMS::XML_NAMESPACES)
        decrypted_body = Nokogiri::XML(java_decrypted_body.children.to_xml)
        expect(decrypted_body.to_xml).to eq(content_document.to_xml)
      end

      it 'has a valid signature' do
        soap_doc = @message_processor.wrap_in_soap(content_document)
        encrypted_xml = @message_processor.encrypt(soap_doc,
                                                   'listDocuments',
                                                   @crypto_options,
                                                   soap_doc.at_xpath(
                                                     '/soapenv:Envelope/soapenv:Body',
                                                     soapenv: VBMS::SoapScum::XMLNamespaces::SOAPENV).children)

        parsed_doc = Nokogiri::XML encrypted_xml
        decrypted_doc = @message_processor.decrypt(parsed_doc, @server_p12_key, @keypass)
        signed_document = Xmldsig::SignedDocument.new(decrypted_doc)
        expect(signed_document.validate(@crypto_options[:client][:certificate])).to be_truthy
      end
    end

    describe '#xmlenc_padding' do
      let(:test_padding_string) do
        <<-jabber
And hast thou slain the Jabberwock?
      Come to my arms, my beamish boy!
O frabjous day! Callooh! Callay!
      He chortled in his joy.
jabber
      end

      it 'can pad all byte string lengths correctly' do
        allow(SecureRandom).to receive(:random_bytes).with(anything).and_raise('Unexpected argument')
        allow(SecureRandom).to receive(:random_bytes).with(1).and_return("\xA0")
        allow(SecureRandom).to receive(:random_bytes).with(2).and_return("\xA0\xB0")
        allow(SecureRandom).to receive(:random_bytes).with(3).and_return("\xA0\xB0\xC0")

        padded = @message_processor.add_xmlenc_padding(4, 'a')
        expect(padded).to eq("a\xA0\xB0\x03")

        padded = @message_processor.add_xmlenc_padding(4, 'ab')
        expect(padded).to eq("ab\xA0\x02")

        padded = @message_processor.add_xmlenc_padding(4, 'abc')
        expect(padded).to eq("abc\x01")

        padded = @message_processor.add_xmlenc_padding(4, 'abcd')
        expect(padded).to eq("abcd\xA0\xB0\xC0\x04")
      end

      it 'can unpad all string lengths correctly' do
        expect(@message_processor.remove_xmlenc_padding(4, "abcda\xA0\xB0\x03\x04")).to eq('abcda')
        expect(@message_processor.remove_xmlenc_padding(4, "abcdab\xA0\x02\x04\x04")).to eq('abcdab')
        expect(@message_processor.remove_xmlenc_padding(4, "abcdabc\x01\x04\x04\x04")).to eq('abcdabc')
        expect(@message_processor.remove_xmlenc_padding(4, "abcdabcd\xA0\xB0\xC0\x04")).to eq('abcdabcd')
      end

      it 'can round trip a string' do
        padded = @message_processor.add_xmlenc_padding(4, test_padding_string)
        unpadded = @message_processor.remove_xmlenc_padding(4, padded)
        expect(unpadded).to eq(test_padding_string)
      end

      it 'raises if encoded padding length is greater than block size' do
        expect { @message_processor.remove_xmlenc_padding(4, "ab\xA0\xB0\x05") }.to raise_error(/violates xmlsec sanity checks/)
      end

      it 'raises if encoded padding length is 0. There is always padding in xmlenc.' do
        expect { @message_processor.remove_xmlenc_padding(4, "ab\xA0\xB0\x00") }.to raise_error(/violates xmlsec sanity checks/)
      end

      it 'raises if encoded padding length is greater than string length.' do
        expect { @message_processor.remove_xmlenc_padding(4, "ab\x04") }.to raise_error(/larger than full plaintext/)
      end

      it 'raises if padded string length is less than encoded padding length' do
        expect { @message_processor.remove_xmlenc_padding(4, "\xA0\xB0\xC0a\xA0\x04") }.to raise_error(/violates xmlsec sanity checks/)
        expect { @message_processor.remove_xmlenc_padding(4, "\xC0ab\x04") }.to raise_error(/violates xmlsec sanity checks/)
        expect { @message_processor.remove_xmlenc_padding(4, "abc\x04") }.to raise_error(/violates xmlsec sanity checks/)
      end

      it 'raises if unpadding an empty string.' do
        expect { @message_processor.remove_xmlenc_padding(4, '') }.to raise_error(/padded_string must be greater than 0 bytes./)
      end
    end
  end
end
