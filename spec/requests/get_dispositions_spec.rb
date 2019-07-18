# frozen_string_literal: true

describe VBMS::Requests::GetDispositions do
  let(:request) do
    VBMS::Requests::GetDispositions.new(claim_id: "600097563")
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
    let(:doc) { parse_strict(fixture("responses/get_dispositions.xml")) }
    subject { request.handle_response(doc) }

    it "should return an array of contentions" do
      expect(subject).to be_an(Array)
      expect(subject.count).to be 4
    end

    it "should load contents correctly" do
      disposition = subject.first
      expect(disposition.claim_id).to eq "600097563"
      expect(disposition.contention_id).to eq "175506"
      expect(disposition.disposition).to eq "Granted"
    end
  end
end
