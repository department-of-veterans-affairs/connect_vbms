require 'spec_helper'
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
      expect(DBLogger).to receive(:new).with("postgres://localhost/drturbotax_development")
      logger = init_logger
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
