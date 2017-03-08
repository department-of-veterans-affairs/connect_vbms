# frozen_string_literal: true
describe VBMS::Requests::GetDocumentContent do
  describe "soap_doc" do
    subject { VBMS::Requests::GetDocumentContent.new("{CE67177F-F63F-436B-8EC7-376606459FA1}") }

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
      request = VBMS::Requests::GetDocumentContent.new("{CE67177F-F63F-436B-8EC7-376606459FA1}")
      xml = fixture("responses/get_document_content_response.xml")
      doc = parse_strict(xml)
      @response = request.handle_response(doc)
    end

    subject { @response }

    it "has some associated content" do
      expect(subject[:content]).to_not be_nil
    end
  end
end
