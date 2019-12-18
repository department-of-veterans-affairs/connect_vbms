# frozen_string_literal: true

describe VBMS::Requests::FindPagedDocumentSeriesReferences do
  describe "soap_doc" do
    subject {  described_class.new(file_number: "784449089") }

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
      request = described_class.new(file_number: "784449089")
      xml = fixture("responses/find_paged_document_series_references_response.xml")
      doc = parse_strict(xml)
      @vbms_docs = request.handle_response(doc)
    end

    subject { @vbms_docs }

    it "should return an array of document_series_references sets" do
      expect(subject).to be_an(Array)
      expect(subject.count).to eq(3)
      expect(subject.first[:documents].count).to eq(2)
    end

    it "should load contents correctly" do
      # document with multiple versions
      doc1 = subject.first[:documents].first
      expect(doc1[:document_id]).to eq "{68A9F5E8-8937-4106-96AE-7066E1FC0E15}"
      expect(doc1[:series_id]).to eq "{95FD13DE-5ADD-488F-BF45-50C0993AEE34}"
      expect(doc1[:version]).to eq "2"
      expect(doc1[:type_description]).to eq "C&#38;P Exam"
      expect(doc1[:type_id]).to eq "356"
      expect(doc1[:source]).to eq "VHA_CUI"
      expect(doc1[:subject]).to eq "Knee"
      expect(doc1[:restricted]).to eq false
      expect(doc1[:received_at]).to eq Date.parse("2014-11-16-04:00")

      # document with alt doc types and one version
      doc2 = subject.third[:documents].first
      expect(doc2[:alt_doc_types].size).to eq 4
      expect(doc2[:document_id]).to eq "{9909502E-E797-421C-BE2F-7650E2F2E7F1}"
      expect(doc2[:type_description]).to eq "Substantive Appeal (In Lieu of VA Form 9)"
      expect(doc2[:type_id]).to eq "857"
      expect(doc2[:source]).to eq "VACOLS"
      expect(doc2[:restricted]).to eq true
      expect(doc2[:received_at]).to eq Date.parse("2014-04-30-04:00")
    end

    it "handles XML errors gracefully" do
      request = described_class.new(file_number: "784449089")
      xml = fixture("responses/find_document_series_reference_fault_response.xml")
      doc = parse_strict(xml)
      expect { request.handle_response(doc) }.to_not raise_error
    end
  end
end
