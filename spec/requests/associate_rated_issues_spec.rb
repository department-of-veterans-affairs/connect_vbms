# frozen_string_literal: true

describe VBMS::Requests::AssociateRatedIssues do
  let(:request) do
    VBMS::Requests::AssociateRatedIssues.new(
      claim_id: "1323123",
      rated_issue_contention_map: { "RATEDISSUEID": "CONTENTIONID" }
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
end
