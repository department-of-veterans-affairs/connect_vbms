require 'spec_helper'
require 'vbms'

describe VBMS::Client do
  before(:example) do
    @client = VBMS::Client.new(
      nil, nil, nil, nil, nil, nil, nil
    )
  end

  describe "remove_mustUnderstand" do
    it "takes a Nokogiri document and deletes the mustUnderstand attribute" do
      doc = Nokogiri::XML(<<-EOF)
      <?xml version="1.0" encoding="UTF-8"?>
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
          <soapenv:Header>
              <wsse:Security soapenv:mustUnderstand="1">
              </wsse:Security>
          </soapenv:Header>
      </soapenv:Envelope>
      EOF

      @client.remove_mustUnderstand(doc)

      expect(doc.to_s).not_to include("mustUnderstand")
    end
  end

  describe "#send" do
    before do
      @client = VBMS::Client.new(
        nil, nil, nil, nil, nil, nil, nil
      )
      @request = double("request",
        file_number: "123456788",
        received_at: DateTime.new(2010, 01, 01),
        first_name: "Joe",
        middle_name: "Eagle",
        last_name: "Citizen",
        exam_name: "Test Fixture Exam",
        pdf_file: "",
        doc_type: "",
        source: "CUI tests",
        name: "uploadDocumentWithAssociations",
        new_mail: "",
        render_xml: "<xml></xml>",
      )
      @response = double("response", :code => 200, :body => "response")
    end

    it "creates two log messages" do
      body = Nokogiri::XML("<xml>body</xml")
      allow(HTTPI).to receive(:post).and_return(@response)
      allow(@client).to receive(:process_response).and_return(nil)
      allow(VBMS).to receive(:encrypted_soap_document_xml).and_return(body.to_s)
      allow(@client).to receive(:inject_saml)
      allow(@client).to receive(:remove_mustUnderstand)
      allow(@client).to receive(:create_body).and_return(body.to_s)
      allow(@client).to receive(:process_body)

      expect(@client).to receive(:log).with(:unencrypted_xml, unencrypted_body: @request.render_xml)
      expect(@client).to receive(:log).with(:request, response_code: @response.code, request_body: body.to_s, response_body: @response.body, request: @request)

      @client.send(@request)
    end
  end

  describe "from_env_vars" do
  let (:vbms_env_vars) { {
        'CONNECT_VBMS_ENV_DIR' => '/my/path/to/credentials',
        'CONNECT_VBMS_URL' => 'http://example.com/fake_vbms',
        'CONNECT_VBMS_KEYFILE' => 'fake_keyfile.some_ext',
        'CONNECT_VBMS_SAML' => 'fake_saml_token',
        'CONNECT_VBMS_KEY' => 'fake_keyname',
        'CONNECT_VBMS_KEYPASS' => 'fake_keypass',
        'CONNECT_VBMS_CACERT' => 'fake_cacert',
        'CONNECT_VBMS_CERT' => 'fake_cert',
      } }

    it "smoke test that it initializes when all environment variables are set" do
      stub_const('ENV', vbms_env_vars)
      expect(VBMS::Client.from_env_vars).not_to be_nil
    end

    describe "required environment variables" do
      it "needs CONNECT_VBMS_ENV_DIR set" do
        vbms_env_vars.delete('CONNECT_VBMS_ENV_DIR')
        stub_const('ENV', vbms_env_vars)
        expect{ VBMS::Client.from_env_vars }.to raise_error(VBMS::EnvironmentError,
                                                            /CONNECT_VBMS_ENV_DIR must be set/)
      end

      it "needs CONNECT_VBMS_URL set" do
        vbms_env_vars.delete('CONNECT_VBMS_URL')
        stub_const('ENV', vbms_env_vars)
        expect{ VBMS::Client.from_env_vars }.to raise_error(VBMS::EnvironmentError,
                                                            /CONNECT_VBMS_URL must be set/)
      end

      it "needs CONNECT_VBMS_KEYFILE set" do
        vbms_env_vars.delete('CONNECT_VBMS_KEYFILE')
        stub_const('ENV', vbms_env_vars)
        expect{ VBMS::Client.from_env_vars }.to raise_error(VBMS::EnvironmentError,
                                                            /CONNECT_VBMS_KEYFILE must be set/)
      end

      it "needs CONNECT_VBMS_SAML set" do
        vbms_env_vars.delete('CONNECT_VBMS_SAML')
        stub_const('ENV', vbms_env_vars)
        expect{ VBMS::Client.from_env_vars }.to raise_error(VBMS::EnvironmentError,
                                                            /CONNECT_VBMS_SAML must be set/)
      end

      it "needs CONNECT_VBMS_KEYPASS set" do
        vbms_env_vars.delete('CONNECT_VBMS_KEYPASS')
        stub_const('ENV', vbms_env_vars)
        expect{ VBMS::Client.from_env_vars }.to raise_error(VBMS::EnvironmentError,
                                                            /CONNECT_VBMS_KEYPASS must be set/)
      end
    end

    describe "required environment variables" do
      it "needs CONNECT_VBMS_KEY set" do
        vbms_env_vars.delete('CONNECT_VBMS_KEY')
        stub_const('ENV', vbms_env_vars)
        expect(VBMS::Client.from_env_vars).not_to be_nil
      end

      it "needs CONNECT_VBMS_CACERT set" do
        vbms_env_vars.delete('CONNECT_VBMS_CACERT')
        stub_const('ENV', vbms_env_vars)
        expect(VBMS::Client.from_env_vars).not_to be_nil
      end

      it "needs CONNECT_VBMS_CERT set" do
        vbms_env_vars.delete('CONNECT_VBMS_CERT')
        stub_const('ENV', vbms_env_vars)
        expect(VBMS::Client.from_env_vars).not_to be_nil
      end
    end
  end
end


describe VBMS::Requests do
  before(:example) do
    @client = VBMS::Client.from_env_vars()
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

        @client.send(request)
      end
    end
  end

  describe "ListDocuments" do
    it "executes succesfully when pointed at VBMS", integration: true do
      request = VBMS::Requests::ListDocuments.new("784449089")

      @client.send(request)
    end
  end

  describe "FetchDocumentById" do
    it "executes succesfully when pointed at VBMS", integration: true do
      # Use ListDocuments to find a document to fetch
      request = VBMS::Requests::ListDocuments.new("784449089")
      result = @client.send(request)

      request = VBMS::Requests::FetchDocumentById.new(result[0].document_id)
      @client.send(request)
    end
  end

  describe "GetDocumentTypes" do
    it "executes succesfully when pointed at VBMS", integration: true do
      request = VBMS::Requests::GetDocumentTypes.new()
      result = @client.send(request)

      expect(result).not_to be_empty

      expect(result[0].type_id).to be_a_kind_of(String)
      expect(result[0].description).to be_a_kind_of(String)
    end
  end
end
