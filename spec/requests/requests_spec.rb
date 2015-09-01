require 'spec_helper'

describe VBMS::Requests do
  before(:example) do
    if ENV.key?('USE_VBMS_TEST_SERVER')
      # We're doing it live and connecting to VBMS test server
      # otherwise, just use @client from above and webmock
      @client = VBMS::Client.from_env_vars
    else
      @client = VBMS::Client.new(
        'http://test.endpoint.url/', fixture_path('test_keystore.jks'), fixture_path('test_samltoken.xml'), nil, 'importkey', nil, nil, nil
      )
    end
  end

  describe "UploadDocumentWithAssociations", integration: true do
    it "executes succesfully when pointed at VBMS" do
      Tempfile.open("tmp") do |t|
        request = VBMS::Requests::UploadDocumentWithAssociations.new(
          "784449089",
          Time.now,
          "Jane",
          "Q",
          "Citizen",
          "knee",
          t.path,
          "356",
          "Connect VBMS test",
          true,
        )

        setup_webmock(@client.endpoint_url, 'upload_document_with_associations', 'uploadDocumentWithAssociationsResponse')
        @client.send(request)

        # other tests?
      end
    end
  end

  describe "ListDocuments" do
    it "executes succesfully when pointed at VBMS", integration: true do
      request = VBMS::Requests::ListDocuments.new("784449089")

      setup_webmock(@client.endpoint_url, 'list_documents', 'listDocumentsResponse')
      @client.send(request)
    end
  end

  describe "FetchDocumentById" do
    it "executes succesfully when pointed at VBMS", integration: true do
      # Use ListDocuments to find a document to fetch
      setup_webmock(@client.endpoint_url, 'list_documents2', 'listDocumentsResponse')
      request = VBMS::Requests::ListDocuments.new("784449089")
      result = @client.send(request)

      request = VBMS::Requests::FetchDocumentById.new(result[0].document_id)
      setup_webmock(@client.endpoint_url, 'fetch_document', 'fetchDocumentResponse')
      @client.send(request)
    end
  end

  describe "GetDocumentTypes" do
    it "executes succesfully when pointed at VBMS", integration: true do
      request = VBMS::Requests::GetDocumentTypes.new()

      setup_webmock(@client.endpoint_url, 'get_document_types', 'getDocumentTypesResponse')
      result = @client.send(request)

      expect(result).not_to be_empty

      expect(result[0].type_id).to be_a_kind_of(String)
      expect(result[0].description).to be_a_kind_of(String)
    end
  end
end
