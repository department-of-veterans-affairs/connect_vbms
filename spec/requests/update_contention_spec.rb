# frozen_string_literal: true

describe VBMS::Requests::UpdateContention do
  let(:contention_hash) do
    {
      id: "303089",
      actionable_item: "false",
      awaiting_response: "unknown",
      claim_id: "600132141",
      classification_cd: nil,
      file_number: "984562385",
      level_status_code: nil,
      medical: "false",
      participant_contention: "unknown",
      secondary_to_contention_id: "1938",
      text: "Service connection for Back, derangement is granted with an evaluation of 30 percent effective June 1, 2018.",
      type_code: "NEW",
      working_contention: "unknown",
      submit_date: Date.new(2018, 8, 6),
      special_issues: [
        {
          code: "1",
          narrative: "narrative",
          inferred: "false",
          id: "1234",
          contention_id: "4321",
          specific_rating: "specific rating"
        },
        {
          code: "2",
          narrative: "narrative2",
          inferred: "false",
          id: "1234",
          contention_id: "4321",
          specific_rating: "specific rating"
        }
      ],
      start_date: Date.new(2018, 8, 6)
    }
  end

  let(:request) do
    VBMS::Requests::UpdateContention.new(
      contention: contention_hash
    )
  end

  context "soap_doc" do
    subject { request }

    it "generates valid SOAP" do
      xml = subject.soap_doc.to_xml
      xsd = Nokogiri::XML::Schema(fixture("soap.xsd"))
      puts xsd
      expect(xsd.errors).to eq []
      errors = xsd.validate(parse_strict(xml))
      expect(errors).to eq []
    end
  end

  context "parsing the XML response" do
    let(:doc) { parse_strict(fixture("responses/update_contention.xml")) }
    subject { request.handle_response(doc) }

    it "should load contents correctly" do
      expect(subject.id).to eq "303090"
      expect(subject.text).to eq(
        "Service connection for Back, derangement is granted with an evaluation of 30 percent effective June 1, 2018."
      )
    end
  end

  context "v5" do
    let(:request) do
      VBMS::Requests::UpdateContention.new(
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

        doc = Nokogiri::XML(xml)
        contention = doc.at_xpath("//claimV5:updateContention/claimV5:contentionToBeUpdated", VBMS::XML_NAMESPACES)

        expect(contention["id"]).to eq(contention_hash[:id])
        expect(contention["claimId"]).to eq(contention_hash[:claim_id])
        expect(contention["fileNumber"]).to eq(contention_hash[:file_number])

        issues = contention.xpath("//cdm:issue")
        expect(issues.length).to eq(contention_hash[:special_issues].length)

        issue = issues.first
        specific_rating = issue.at_xpath("//cdm:specificRating")
        expect(specific_rating.text).to eq(contention_hash[:special_issues][0][:specific_rating])
      end
    end

    context "parsing the XML response" do
      let(:doc) { parse_strict(fixture("responses/update_contention_v5.xml")) }
      subject { request.handle_response(doc) }

      it "should load contents correctly" do
        expect(subject.id).to eq "303090"
        expect(subject.text).to eq(
          "Service connection for Back, derangement is granted with an evaluation of 30 percent effective June 1, 2018."
        )
      end
    end
  end
end
