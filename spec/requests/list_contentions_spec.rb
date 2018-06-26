# frozen_string_literal: true
describe VBMS::Requests::ListContentions do
  let(:request) do 
    VBMS::Requests::ListContentions.new(claim_id: "1323123")
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
    let(:doc) { parse_strict(fixture("responses/list_contentions.xml")) }
    subject { request.handle_response(doc) }

    it "should return an array of contentions" do
      puts subject
      expect(subject).to be_an(Array)
      expect(subject.count).to be 11
    end

    it "should load contents correctly" do
      contention = subject.first
      expect(contention.id).to eq "290355"
      expect(contention.text).to eq "Contention DS example"
    end
  end

  context "v5" do
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

    context "parsing the XML response",
            skip: "need to get example response from VBMS" do
      let(:doc) { parse_strict(fixture("responses/list_contentions_v5.xml")) }
      subject { request.handle_response(doc) }

      it "should return an array of contentions" do
        puts subject
        expect(subject).to be_an(Array)
        expect(subject.count).to be 11
      end

      it "should load contents correctly" do
        contention = subject.first
        expect(contention.id).to eq "290355"
        expect(contention.text).to eq "Contention DS example"
      end
    end
  end
end
