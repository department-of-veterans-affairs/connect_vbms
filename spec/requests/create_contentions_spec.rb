# frozen_string_literal: true
describe VBMS::Requests::CreateContentions do
  let(:request) do 
    VBMS::Requests::CreateContentions.new(
      veteran_file_number: "1232",
      claim_id: "1323123",
      contentions: ["Billy One", "Billy Two", "Billy Three"]
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
    let(:doc) { parse_strict(fixture("responses/create_contentions.xml")) }
    subject { request.handle_response(doc) }

    it "should return an array of contentions" do
      puts subject
      expect(subject).to be_an(Array)
      expect(subject.count).to be 12
    end

    it "should load contents correctly" do
      contention = subject.first
      expect(contention.id).to eq "290355"
      expect(contention.text).to eq "Contention DS example & more"
    end
  end

  context "v5" do
    let(:request) do 
      VBMS::Requests::CreateContentions.new(
        veteran_file_number: "1232",
        claim_id: "1323123",
        contentions: ["Billy One", "Billy Two", "Billy Three"],
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

    context "parsing the XML response",
            skip: "there is currently a bug in VBMS v5, so we do not have a fixture response" do
      let(:doc) { parse_strict(fixture("responses/create_contentions_v5.xml")) }
      subject { request.handle_response(doc) }

      it "should return an array of contentions" do
        puts subject
        expect(subject).to be_an(Array)
        expect(subject.count).to be 12
      end

      it "should load contents correctly" do
        contention = subject.first
        expect(contention.id).to eq "290355"
        expect(contention.text).to eq "Contention DS example"
      end
    end
  end
end
