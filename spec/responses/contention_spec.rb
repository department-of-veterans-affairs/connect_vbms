# frozen_string_literal: true

require "spec_helper"

describe VBMS::Responses::Contention do
  describe "create_from_xml" do
    let(:xml_string) { File.open(fixture_path("responses/list_contentions.xml")).read }
    let(:xml) { Nokogiri::XML(xml_string) }
    let(:doc) do
      xml.at_xpath("//claimV4:listContentionsResponse/claimV4:listOfContentions", VBMS::XML_NAMESPACES)
    end

    subject { VBMS::Responses::Contention.create_from_xml(doc) }

    specify do
      expect(subject.id).to eq("290355")
    end
  end

  describe "create from xml v5 with multiple special issues" do
    let(:xml_string) { File.open(fixture_path("responses/list_contentions_v5.xml")).read }
    let(:xml) { Nokogiri::XML(xml_string) }
    let(:doc) do
      xml.at_xpath("//claimV5:listContentionsResponse/claimV5:listOfContentions", VBMS::XML_NAMESPACES)
    end

    subject { VBMS::Responses::Contention.create_from_xml(doc) }

    it "has 2 special issues" do
      expect(subject.id).to eq("290355")
      expect(subject.actionable_item).to eq("false")
      expect(subject.contention_category).to eq("unknown")
      expect(subject.claim_id).to eq("600118427")
      expect(subject.file_number).to eq("241573462")
      expect(subject.medical).to eq("false")
      expect(subject.participant_contention).to eq("unknown")
      expect(subject.secondary_to_contention_id).to eq("7792")
      expect(subject.title).to eq("Contention DS example")
      expect(subject.type_code).to eq("NEW")
      expect(subject.working_contention).to eq("unknown")
      expect(subject.classification_cd).to eq("1234")
      expect(subject.level_status_code).to eq("P")
      expect(subject.disposition).to eq("disposition")
      expect(subject.special_issues.length).to eq(2)
    end
  end

  describe "create from xml v5 with one special issues" do
    let(:xml_string) { File.open(fixture_path("responses/list_contentions_v5.xml")).read }
    let(:xml) { Nokogiri::XML(xml_string) }
    let(:doc) do
      xml.xpath("//claimV5:listContentionsResponse/claimV5:listOfContentions", VBMS::XML_NAMESPACES)[1]
    end

    subject { VBMS::Responses::Contention.create_from_xml(doc) }

    it "has one special issues" do
      expect(subject.id).to eq("290356")
      expect(subject.actionable_item).to eq("false")
      expect(subject.claim_id).to eq("600118427")
      expect(subject.file_number).to eq("241573462")
      expect(subject.medical).to eq("false")
      expect(subject.participant_contention).to eq("unknown")
      expect(subject.secondary_to_contention_id).to eq("7792")
      expect(subject.title).to eq("Contention DS example")
      expect(subject.type_code).to eq("NEW")
      expect(subject.working_contention).to eq("unknown")
      expect(subject.special_issues.length).to eq(1)
    end
  end

  describe "create from xml v5 with no special issues" do
    let(:xml_string) { File.open(fixture_path("responses/list_contentions_v5.xml")).read }
    let(:xml) { Nokogiri::XML(xml_string) }
    let(:doc) do
      xml.xpath("//claimV5:listContentionsResponse/claimV5:listOfContentions", VBMS::XML_NAMESPACES)[2]
    end

    subject { VBMS::Responses::Contention.create_from_xml(doc) }

    it "has no special issues" do
      expect(subject.id).to eq("290357")
      expect(subject.actionable_item).to eq("false")
      expect(subject.claim_id).to eq("600118427")
      expect(subject.file_number).to eq("241573462")
      expect(subject.medical).to eq("false")
      expect(subject.participant_contention).to eq("unknown")
      expect(subject.secondary_to_contention_id).to eq("7792")
      expect(subject.title).to eq("Contention DS example")
      expect(subject.type_code).to eq("NEW")
      expect(subject.working_contention).to eq("unknown")
      expect(subject.special_issues.length).to eq(0)
    end
  end

  describe "serialization" do
    let(:attrs) do
      {
        id: "290355",
        text: "Contention DS example",
        start_date: "2017-11-22-05:00",
        submit_date: "2017-11-20-05:00",
        actionable_item: "false",
        awaiting_response: "unknown",
        claim_id: "600118427",
        classification_cd: "1234",
        contention_category: "unknown",
        file_number: "241573462",
        level_status_code: "P",
        medical: "false",
        participant_contention: "unknown",
        secondary_to_contention_id: "7792",
        type_code: "NEW",
        working_contention: "unknown"
      }
    end

    subject { VBMS::Responses::Contention.new(attrs) }

    it "should respond to to_h" do
      expect(subject.to_h).to be_a(Hash)
      expect(subject.to_h).to include(attrs)
    end

    it "should respond to to_s" do
      expect(subject.to_s).to be_a(String)
    end

    it "should contain the attributes in to_s" do
      s = subject.to_s
      expect(s).to include(attrs[:id])
      expect(s).to include(attrs[:text])
      expect(s).to include(attrs[:start_date])
      expect(s).to include(attrs[:submit_date])
      expect(s).to include(attrs[:actionable_item])
      expect(s).to include(attrs[:awaiting_response])
      expect(s).to include(attrs[:claim_id])
      expect(s).to include(attrs[:classification_cd])
      expect(s).to include(attrs[:contention_category])
      expect(s).to include(attrs[:file_number])
      expect(s).to include(attrs[:level_status_code])
      expect(s).to include(attrs[:medical])
      expect(s).to include(attrs[:participant_contention])
      expect(s).to include(attrs[:secondary_to_contention_id])
      expect(s).to include(attrs[:type_code])
      expect(s).to include(attrs[:working_contention])
    end

    it "should respond to inspect" do
      expect(subject.inspect).to eq(subject.to_s)
    end
  end
end
