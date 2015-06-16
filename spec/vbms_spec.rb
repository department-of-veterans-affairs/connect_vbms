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
end


describe VBMS::Requests do
  before(:example) do
    @client = VBMS::Client.FromEnvVars()
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
          true,
        )

        @client.send(request)
      end
    end
  end

  describe "ListDocuments" do
    it "executes succesfully when pointed at VBMS" do
      request = VBMS::Requests::ListDocuments.new("784449089")

      @client.send(request)
    end
  end

  describe "FetchDocumentById" do
    it "executes succesfully when pointed at VBMS" do
      # Use ListDocuments to find a document to fetch
      request = VBMS::Requests::ListDocuments.new("784449089")
      result = @client.send(request)

      request = VBMS::Requests::FetchDocumentById.new(result[0].document_id)
      @client.send(request)
    end
  end

  describe "GetDocumentTypes" do
    it "executes succesfully when pointed at VBMS" do
      request = VBMS::Requests::GetDocumentTypes.new()
      result = @client.send(request)

      expect(result).not_to be_empty
    end
  end
end
