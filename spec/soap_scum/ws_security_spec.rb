def wrap_in_soap(doc)
  Nokogiri::XML::Builder.new do |xml|
    xml["soapenv"].Envelope(VBMS::Requests::NAMESPACES) do
      xml["soapenv"].Body { xml.parent << doc.root }
    end
  end.doc
end

describe SoapScum::WSSecurity do
  let(:client_keyfile) { fixture_path("test_client.p12") }
  let(:server_keyfile) { fixture_path("test_client.p12") }
  let(:server_cert) { fixture_path("test_server.crt") }
  let(:client_cert) { fixture_path("test_client.crt") }
  let(:server_java_keyfile) { fixture_path("test_server.jks") }
  let(:keypass) { "importkey" }

  let(:content_xml) do
    <<-XML
      <v4:listDocuments>
        <v4:fileNumber>784449089</v4:fileNumber>
      </v4:listDocuments>
    XML
  end
  let(:content_document) { Nokogiri::XML(content_xml) }
  let(:soap_document) { wrap_in_soap(content_document) }

  before do
    SoapScum::WSSecurity.configure(
      client_keyfile: client_keyfile,
      server_cert: server_cert,
      keypass: keypass
    )
  end

  describe '#encrypt' do
    let(:signed_elements) do
      [["/soapenv:Envelope/soapenv:Body", { soapenv: SoapScum::XMLNamespaces::SOAPENV }, "Content"]]
    end

    let(:soap_schema) { Nokogiri::XML::Schema(fixture("soap.xsd")) }
    let(:result) { SoapScum::WSSecurity.encrypt(soap_document, signed_elements) }

    it "returns valid SOAP" do
      expect(soap_schema.validate(result).size).to eq(0)
    end

    it "is verifyable and decryptable by Java WSSecurity library" do
      decrypted_doc = java_decrypt_xml(result, fixture_path("test_server.jks"), keypass, true)
      decrypted_doc = Nokogiri::XML(decrypted_doc)

      expect(decrypted_doc.xpath("//v4:fileNumber").text).to eq("784449089")
    end

    it "is decryptable by Ruby WSSecurity library" do
      # Configure WSSecurity with reverse certificates for decryption
      SoapScum::WSSecurity.configure(
        client_keyfile: server_keyfile,
        server_cert: client_cert,
        keypass: keypass
      )

      decrypted_doc = SoapScum::WSSecurity.decrypt(result.to_xml)
      decrypted_doc = Nokogiri::XML(decrypted_doc)

      expect(decrypted_doc.xpath("//v4:fileNumber").text).to eq("784449089")
    end
  end

  describe '#decrypt' do
    let(:java_encrypted_xml) { encrypted_xml_buffer(soap_document, fixture_path("test_server.jks"), "listDocuments") }

    it "it decrypts soap message encrypted by Java WSSecurity library" do
      decrypted_doc = SoapScum::WSSecurity.decrypt(java_encrypted_xml)
      decrypted_doc = Nokogiri::XML(decrypted_doc)

      expect(decrypted_doc.xpath("//v4:fileNumber").text).to eq("784449089")
    end
  end
end
