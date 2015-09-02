require 'spec_helper'

describe VBMS::Requests::UploadDocumentWithAssociations do
  subject { VBMS::Requests::UploadDocumentWithAssociations.new(
      '123456788',
      Time.now.utc,
      'Joe', 'Eagle', 'Citizen',
      'UDWA test exam name',
      '/pdf/does/not/exist',
      'doc_type',
      'UDWA test source',
      'UDWA new mail') }

  describe "render_xml" do
    it "generates valid XML" do
      xml = subject.render_xml
      doc = Nokogiri::XML::Document.parse(xml, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
      xsd = Nokogiri::XML::Schema(File.read("spec/soap.xsd"))
      expect(xsd.errors).to eq []
      errors = xsd.validate(Nokogiri::XML(xml))
      expect(errors).to eq []
    end
  end

  describe "parsing the XML" do
    before do
      xml = File.read(fixture_path('requests/upload_document_with_associations.xml'))
      @doc = Nokogiri::XML(xml)
      @response = subject.handle_response(@doc)
    end

    # TODO: should we do more with this?
    it "should just return the document" do
      expect(@response).to eq(@doc)
    end
  end
end
