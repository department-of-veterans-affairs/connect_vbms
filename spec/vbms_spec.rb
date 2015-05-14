# TODO: remove this once we can put our source code in `lib/`
$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "src")

require 'vbms'

def env_path(env_dir, env_var_name)
  value = ENV[env_var_name]
  if value.nil?
    return nil
  else
    return File.join(env_dir, value)
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
      path = nil
      Tempfile.open("tmp") do |t|
        path = t.path
      end

      request = VBMS::Requests::UploadDocumentWithAssociations.new(
        "784449089",
        Time.now,
        "Jane",
        "Q",
        "Citizen",
        "knee",
        path,
        "356",
        "Connect VBMS test",
        true,
      )

      @client.send(request)
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
