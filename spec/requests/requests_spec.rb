require "spec_helper"

describe VBMS::Requests do
  before(:example) do
    @client = if ENV.key?("CONNECT_VBMS_RUN_EXTERNAL_TESTS")
                # We're doing it live and connecting to VBMS test server
                # otherwise, just use @client from above and webmock
                VBMS::Client.from_env_vars(env_name: ENV["CONNECT_VBMS_ENV"])
              else
                new_test_client
              end
  end

  describe "UploadDocumentWithAssociations" do
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
          true
        )

        webmock_multipart_response("#{@client.base_url}#{VBMS::ENDPOINTS[:efolder]}",
                                   "upload_document_with_associations",
                                   "uploadDocumentWithAssociationsResponse")
        @client.send_request(request)
      end
    end
  end

  describe "ListDocuments" do
    it "executes succesfully when pointed at VBMS" do
      request = VBMS::Requests::ListDocuments.new("784449089")

      webmock_soap_response("#{@client.base_url}#{VBMS::ENDPOINTS[:efolder]}", "list_documents", "listDocumentsResponse")
      @client.send_request(request)
    end
  end

  describe "FetchDocumentById" do
    it "executes succesfully when pointed at VBMS" do
      # Use ListDocuments to find a document to fetch

      webmock_soap_response("#{@client.base_url}#{VBMS::ENDPOINTS[:efolder]}", "list_documents", "listDocumentsResponse")

      request = VBMS::Requests::ListDocuments.new("784449089")
      result = @client.send_request(request)

      request = VBMS::Requests::FetchDocumentById.new(result[0].document_id)
      webmock_soap_response("#{@client.base_url}#{VBMS::ENDPOINTS[:efolder]}", 
                            "fetch_document",
                            "fetchDocumentResponse")
      @client.send_request(request)
    end
  end

  describe "GetDocumentTypes" do
    it "executes succesfully when pointed at VBMS" do
      request = VBMS::Requests::GetDocumentTypes.new

      webmock_soap_response("#{@client.base_url}#{VBMS::ENDPOINTS[:efolder]}",
                            "get_document_types",
                            "getDocumentTypesResponse")
      result = @client.send_request(request)

      expect(result).not_to be_empty

      expect(result[0].type_id).to be_a_kind_of(String)
      expect(result[0].description).to be_a_kind_of(String)
    end
  end

  describe "EstablishClaim" do
    let(:veteran_record) do
      {
        file_number: "561349920",
        sex: "M",
        first_name: "Stan",
        last_name: "Stanman",
        ssn: "796164121",
        address_line1: "Shrek's Swamp",
        address_line2: "",
        address_line3: "",
        city: "Charleston",
        state: "SC",
        country: "USA",
        zip_code: "29401"
      }
    end

    # NOTE: In order for this to pass when connected to VBMS
    # the information here cannot be a duplicate of an existing
    # claim. The easiest way to do this is to increment the `end_product_modifier`
    let(:claim) do
      {
        benefit_type_code: "1",
        payee_code: "00",
        station_of_jurisdiction: "317",
        end_product_code: "070CERT2AMC",
        end_product_modifier: "071",
        end_product_label: "AMC-Cert to BVA",
        predischarge: false,
        gulf_war_registry: false,
        date: 20.days.ago.to_date,
        suppress_acknowledgment_letter: false
      }
    end

    it "executes succesfully when pointed at VBMS" do
      request = VBMS::Requests::EstablishClaim.new(veteran_record, claim)

      webmock_soap_response("#{@client.base_url}#{VBMS::ENDPOINTS[:claims]}",
                            "establish_claim",
                            "establishedClaim")

      result = @client.send_request(request)

      expect(result.claim_id).to be_a_kind_of(String)
    end
  end
end
