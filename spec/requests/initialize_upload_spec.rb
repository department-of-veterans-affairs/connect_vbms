# frozen_string_literal: true
describe VBMS::Requests::InitializeUpload do
  describe "soap_doc" do
    subject do 
      VBMS::Requests::InitializeUpload.new(content_hash: "1a1389d7934dc6444ce6471beb9fcf16ff57221f",
                                           filename: "test1.pdf",
                                           file_number: "784449089",
                                           va_receive_date: Time.now,
                                           doc_type: "356",
                                           source: "Connect VBMS test") 
    end

    it "generates valid SOAP" do
      xml = subject.soap_doc.to_xml
      xsd = Nokogiri::XML::Schema(fixture("soap.xsd"))
      expect(xsd.errors).to eq []
      errors = xsd.validate(parse_strict(xml))
      expect(errors).to eq []
    end
  end

  describe "parsing the XML" do
    before(:all) do
      request = VBMS::Requests::InitializeUpload.new(content_hash: "1a1389d7934dc6444ce6471beb9fcf16ff57221f",
                                                     filename: "test1.pdf",
                                                     file_number: "784449089",
                                                     va_receive_date: Time.now,
                                                     doc_type: "356",
                                                     source: "Connect VBMS test")
      xml = fixture("responses/initialize_upload.xml")
      doc = parse_strict(xml)
      @response = request.handle_response(doc)
    end

    subject { @response }

    it "returns upload token" do
      expect(subject[:upload_token]).to eq "{1587FC2D-63FA-40EA-8E59-D99FF790395B}"
    end
  end
end
