# frozen_string_literal: true

describe VBMS::Requests::ListTypeCategory do
  describe "soap_doc" do
    subject { VBMS::Requests::ListTypeCategory.new }

    it "generates valid SOAP" do
      xml = subject.soap_doc.to_xml
      xsd = Nokogiri::XML::Schema(fixture("soap.xsd"))
      expect(xsd.errors).to eq []
      errors = xsd.validate(parse_strict(xml))
      expect(errors).to eq []
    end
  end

  describe "parsing the XML response" do
    before(:all) do
      request = VBMS::Requests::ListTypeCategory.new
      xml = fixture("responses/list_type_category_response.xml")
      doc = parse_strict(xml)
      @vbms_docs = request.handle_response(doc)
    end

    subject { @vbms_docs }

    it "should return an array of document types" do
      expect(subject).to be_an(Array)
      expect(subject.count).to be 4 # how many are in the sample file
    end

    it "should load contents correctly" do
      doc1 = subject.first
      expect(doc1[:type_id]).to eq "708"
      expect(doc1[:description]).to eq "099 request code Camp Lejeune"
    end
  end
end
