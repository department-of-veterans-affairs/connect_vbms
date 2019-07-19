# frozen_string_literal: true

require "spec_helper"

describe VBMS::Responses::Disposition do
  describe "create_from_xml" do
    let(:xml_string) { File.open(fixture_path("responses/get_dispositions.xml")).read }
    let(:xml) { Nokogiri::XML(xml_string) }
    let(:doc) do
      xml.at_xpath("//claimV5:getDispositionsResponse", VBMS::XML_NAMESPACES).elements.first.attributes
    end

    subject { VBMS::Responses::Disposition.create_from_xml(doc) }

    specify do
      expect(subject.claim_id).to eq("600097563")
    end
  end

  describe "serialization" do
    let(:attrs) do
      { claim_id: "600097563", contention_id: "175506", disposition: "Granted" }
    end
    subject { VBMS::Responses::Disposition.new(attrs) }

    it "should respond to to_h" do
      expect(subject.to_h).to be_a(Hash)
      expect(subject.to_h).to include(attrs)
    end

    it "should respond to to_s" do
      expect(subject.to_s).to be_a(String)
    end

    it "should contain the attributes in to_s" do
      s = subject.to_s
      expect(s).to include(attrs[:claim_id])
      expect(s).to include(attrs[:contention_id])
      expect(s).to include(attrs[:disposition])
    end

    it "should respond to inspect" do
      expect(subject.inspect).to eq(subject.to_s)
    end
  end
end
