# TODO: remove this once we can put our source code in `lib/`
$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "src")

require 'send'

RSpec.describe 'send.rb' do
  context "when CONNECT_VBMS_POSTGRES is set" do
    before do
      ENV["CONNECT_VBMS_POSTGRES"] = "postgres://localhost/drturbotax_development"
    end

    after do
      ENV.delete "CONNECT_VBMS_POSTGRES"
    end

    it "should initialize a DBLogger" do
      expect(PG).to receive(:connect).with('localhost', nil, nil, nil, 'drturbotax_development', nil, nil)
      logger = init_logger
      expect(logger.class).to eq DBLogger
    end
  end

  context "when CONNECT_VBMS_POSTGRES is not set" do
    before do
      ENV.delete "CONNECT_VBMS_POSTGRES"
    end

    it "should return nil" do
      logger = init_logger
      expect(logger.class).to eq NilClass
    end
  end
end
