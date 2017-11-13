# frozen_string_literal: true
describe VBMS::Requests::FindDocumentVersionReference do
  describe "soap_doc" do
    subject {  VBMS::Requests::FindDocumentVersionReference.new("784449089") }

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
      request = VBMS::Requests::FindDocumentVersionReference.new("784449089")
      xml = fixture("responses/find_document_version_reference_response.xml")
      doc = parse_strict(xml)
      @vbms_docs = request.handle_response(doc)
    end

    subject { @vbms_docs }

    it "should return an array of documents" do
      expect(subject).to be_an(Array)
      expect(subject.count).to be 124 # how many are in the sample file
    end

    it "should load contents correctly" do
      doc1 = subject.first
      expect(doc1[:document_id]).to eq "{CB958142-F063-489D-80DC-6C8A7A5B4319}"
      expect(doc1[:type_description]).to eq "C&#38;P Exam"
      expect(doc1[:type_id]).to eq "356"
      expect(doc1[:source]).to eq "VHA_CUI"
      expect(doc1[:subject]).to eq "knee"
      expect(doc1[:restricted]).to eq false
      expect(doc1[:received_at]).to eq Date.parse("2017-03-29-04:00")
    end
  end
end
