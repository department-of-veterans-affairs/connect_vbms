# frozen_string_literal: true

describe VBMS::Requests::RemoveContention do
  let(:contention_hash) do
    {
      submit_date: Date.new(2018, 8, 6),
      start_date: Date.new(2018, 8, 6),
      actionable_item: "false",
      awaiting_response: "unknown",
      claim_id: "600132141",
      classification_cd: nil,
      contention_category: nil,
      file_number: "984562385",
      level_status_code: nil,
      id: "303089",
      medical: "false",
      participant_contention: "unknown",
      secondary_to_contention_id: "1938",
      text: "Service connection for Back, derangement is granted with an evaluation of 30 percent effective June 1, 2018.",
      type_code: "NEW",
      working_contention: "unknown"
    }
  end

  let(:request) do
    VBMS::Requests::RemoveContention.new(
      contention: contention_hash
    )
  end

  context "soap_doc" do
    subject { request }

    it "generates valid SOAP" do
      xml = subject.soap_doc.to_xml
      xsd = Nokogiri::XML::Schema(fixture("soap.xsd"))
      expect(xsd.errors).to eq []
      errors = xsd.validate(parse_strict(xml))
      expect(errors).to eq []
    end
  end

  context "parsing the XML response" do
    let(:doc) { parse_strict(fixture("responses/remove_contention.xml")) }
    subject { request.handle_response(doc) }

    it "should return true" do
      expect(subject).to eq("true")
    end
  end

  context "v5" do
    let(:request) do
      VBMS::Requests::RemoveContention.new(
        contention: contention_hash,
        v5: true
      )
    end

    context "soap_doc" do
      subject { request.soap_doc }

      it "generates valid SOAP" do
        xml = subject.to_xml
        xsd = Nokogiri::XML::Schema(fixture("soap.xsd"))
        expect(xsd.errors).to eq []
        errors = xsd.validate(parse_strict(xml))
        expect(errors).to eq []
      end
    end

    context "parsing the XML response" do
      let(:doc) { parse_strict(fixture("responses/remove_contention_v5.xml")) }
      subject { request.handle_response(doc) }

      it "should return true" do
        expect(subject).to eq("true")
      end
    end
  end
end
