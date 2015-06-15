# TODO: remove this once we can put our source code in `lib/`
$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "src")

require 'spec_helper'
require 'vbms'

RSpec.describe VBMS, focus:true do
  describe 'shell_java' do
    context "with a nonsense CLASSPATH" do
      before do
        @old_classpath = VBMS::CLASSPATH
        VBMS::CLASSPATH = "/does/not/exist"
      end

      after do
        VBMS::CLASSPATH = @old_classpath
      end

      it "should raise a JavaExecutionError" do
        expect {VBMS::shell_java "failure"}.to raise_error VBMS::JavaExecutionError
        begin
          VBMS::shell_java "failure"
        rescue VBMS::JavaExecutionError => e
          expect(e.message).to eq <<-EOF
Error running cmd: java -classpath '/does/not/exist' failure 2>&1
Output: Error: Could not find or load main class failure
          EOF
        end
      end
    end

    it "should succesfully encrypt a file" do
      xml = File.expand_path "spec/data/unencrypted_xml.xml"
      keyfile = File.expand_path "spec/data/key.key"
      output = VBMS::shell_java("EncryptSOAPDocument #{xml} #{keyfile} bananas bananas")
      puts output
    end
  end
end

RSpec.describe VBMS::Client do
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


RSpec.describe VBMS::Requests do
  before(:example) do
    env_dir = File.join(ENV["CONNECT_VBMS_ENV_DIR"], "test")
    @client = VBMS::Client.new(
      ENV["CONNECT_VBMS_URL"],
      env_path(env_dir, "CONNECT_VBMS_KEYFILE"),
      env_path(env_dir, "CONNECT_VBMS_SAML"),
      env_path(env_dir, "CONNECT_VBMS_KEY"),
      ENV["CONNECT_VBMS_KEYPASS"],
      env_path(env_dir, "CONNECT_VBMS_CACERT"),
      env_path(env_dir, "CONNECT_VBMS_CERT"),
    )
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
