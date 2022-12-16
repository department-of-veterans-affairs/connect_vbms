# frozen_string_literal: true

describe VBMS::Requests::FindDocumentVersionReferenceByDateRange do
  describe "soap_doc" do
    subject do
      VBMS::Requests::FindDocumentVersionReferenceByDateRange.new(
        file_number: "784449089", begin_date_range: Time.new(2022, 10, 10), end_date_range: Time.now
      )
    end
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
      request = VBMS::Requests::FindDocumentVersionReferenceByDateRange.new(
        file_number: "784449089", begin_date_range: Time.new(2017, 0o3, 22), end_date_range: Time.new(2017, 0o3, 29)
      )
      xml = fixture("responses/find_document_version_reference_by_date_range_response.xml")
      doc = parse_strict(xml)
      @vbms_docs = request.handle_response(doc)
    end
    subject { @vbms_docs }
    it "should return an array of documents with an upload date within the date range" do
      expect(subject.map { |doc| Time.new(2017, 0o3, 22).to_datetime <= doc.upload_date.to_datetime }).to all(be_truthy)
      expect(subject.map { |doc| Time.new(2017, 0o3, 29).to_datetime >= doc.upload_date.to_datetime }).to all(be_truthy)
      expect(subject).to be_an(Array)
      expect(subject.count).to be 7
    end
    it "should load contents correctly" do
      doc1 = subject.first
      expect(doc1[:document_id]).to eq "{CB958142-F063-489D-80DC-6C8A7A5B4319}"
      expect(doc1[:series_id]).to eq "{623D6B8A-D599-4E2D-947E-A2CA2955C4DD}"
      expect(doc1[:version]).to eq "2"
      expect(doc1[:type_description]).to eq "C&#38;P Exam"
      expect(doc1[:type_id]).to eq "356"
      expect(doc1[:source]).to eq "VHA_CUI"
      expect(doc1[:subject]).to eq "knee"
      expect(doc1[:restricted]).to eq false
      expect(doc1[:received_at]).to eq Date.parse("2017-03-29-04:00")
      expect(doc1[:upload_date]).to eq Date.parse("2017-03-29-04:00")
    end
  end
end
