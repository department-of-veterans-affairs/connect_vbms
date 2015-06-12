# TODO: remove this once we can put our source code in `lib/`
$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "src")

require 'byebug'
require 'send'

RSpec.describe 'send.rb' do
  it "should initialize a postgres logger if CONNECT_VBMS_POSTGRES is set" do
    ENV["CONNECT_VBMS_POSTGRES"] = "postgres://localhost/drturbotax_development"
    expect(PG).to receive(:connect).with('localhost', nil, nil, nil, 'drturbotax_development', nil, nil)
    logger = init_logger
    expect(logger.class).to eq VBMS::DBLogger
    ENV.delete "CONNECT_VBMS_POSTGRES"
  end

  it "should return nil if CONNECT_VBMS_POSTGRES is not set" do
    logger = init_logger
    expect(logger.class).to eq NilClass
  end
end
