require 'spec_helper'

describe VBMS::Requests::GetDocumentTypes do
  describe "handle_response" do
    before(:all) do
      request = VBMS::Requests::GetDocumentTypes.new
      xml = File.read(fixture_path('requests/get_document_types.xml'))
      doc = Nokogiri::XML(xml)
      @response = request.handle_response(doc)
    end

    subject { @response }

    it "should return an array of DocumentType objects" do
      expect(subject).to be_an(Array)
      expect(subject).to all(be_a(VBMS::DocumentType))
      expect(subject.count).to eq(512)
    end

    it "should assign values properly to the DocumentType object" do
      dt = subject.first
      expect(dt.type_id).to eq('431')
      expect(dt.description).to eq('VA 21-4706c Court Appointed Fiduciarys Accounting')
    end
  end
end
