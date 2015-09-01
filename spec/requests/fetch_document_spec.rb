require 'spec_helper'

describe VBMS::Requests::FetchDocumentById do
  describe "parsing the XML" do
    before(:all) do
      request = VBMS::Requests::FetchDocumentById.new('')
      xml = File.read(fixture_path('requests/fetch_document.xml'))
      doc = Nokogiri::XML(xml)
      @response = request.handle_response(doc)
    end

    subject { @response }

    it "should return a DocumentWithContent object" do
      expect(subject).to be_a(VBMS::DocumentWithContent)
    end

    it "has valid document information" do
      doc = subject.document

      expect(doc.document_id).to eq('{9E364101-AFDD-49A7-A11F-602CCF2E5DB5}')
      expect(doc.filename).to eq('tmp20150506-94244-6zotzp')
      expect(doc.doc_type).to eq('356')
      expect(doc.source).to eq('VHA_CUI')
      expect(doc.received_at).to eq(Time.parse('2015-05-06-04:00').to_date)
    end

    it "has some associated content" do
      expect(subject.content).to_not be_nil
    end
  end
end
