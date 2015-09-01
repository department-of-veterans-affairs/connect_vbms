require 'spec_helper' do
  describe VBMS::Requests::UploadDocumentWithAssociations do
    describe "parsing the XML" do
      before(:all) do
        request = VBMS::Requests::FetchDocumentById.new('')
        xml = File.read(fixture_path('requests/upload_document_with_associations.xml'))
        doc = Nokogiri::XML(xml)
        @response = request.handle_response(doc)
      end

      subject { @response }

      # TODO: should we do more with this?
      it "should just return the document" do
        expect(subject).to eq(doc)
      end
    end
  end
end
