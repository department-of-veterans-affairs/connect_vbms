# frozen_string_literal: true
describe VBMS::Requests::UploadDocument do
  before(:all) do
    @file = Tempfile.new("foo")
    @file.write("hello world")
  end

  describe "soap_doc" do
    subject do 
      VBMS::Requests::UploadDocument.new(upload_token: "{1587FC2D-63FA-40EA-8E59-D99FF790395B}",
                                         filepath: @file.path) 
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
      request = VBMS::Requests::UploadDocument.new(upload_token: "{1587FC2D-63FA-40EA-8E59-D99FF790395B}",
                                                   filepath: @file.path)
      xml = fixture("responses/upload_document.xml")
      doc = parse_strict(xml)
      @response = request.handle_response(doc)
    end

    subject { @response }

    it "returns upload token" do
      expect(subject[:upload_document_response][:@new_document_version_ref_id]).to eq "{2F1A4BCB-F80F-45BF-82A6-CC9E5DAF3B81}"
    end
  end

  after(:all) do
    @file.close
    @file.unlink
  end
end
