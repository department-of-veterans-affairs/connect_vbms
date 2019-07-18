# frozen_string_literal: true

require "spec_helper"

describe VBMS::Client do
  before(:example) do
    @client = new_test_client
  end

  describe "remove_must_understand" do
    it "takes a Nokogiri document and deletes the mustUnderstand attribute" do
      doc = Nokogiri::XML(<<-XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <soapenv:Envelope
           xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
           xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
        <soapenv:Header>
          <wsse:Security soapenv:mustUnderstand="1">
          </wsse:Security>
        </soapenv:Header>
      </soapenv:Envelope>
      XML

      @client.remove_must_understand(doc)

      expect(doc.to_s).not_to include("mustUnderstand")
    end
  end

  describe "#send" do
    before do
      @client = new_test_client

      @request = double("request",
                        file_number: "123456788",
                        received_at: DateTime.new(2010, 0o1, 0o1),
                        first_name: "Joe",
                        middle_name: "Eagle",
                        last_name: "Citizen",
                        exam_name: "Test Fixture Exam",
                        pdf_file: "",
                        doc_type: "",
                        source: "CUI tests",
                        name: "uploadDocumentWithAssociations",
                        new_mail: "",
                        multipart?: false,
                        soap_doc: VBMS::Requests.soap { "body" },
                        signed_elements: [["/soapenv:Envelope/soapenv:Body",
                                           { soapenv: SoapScum::XMLNamespaces::SOAPENV },
                                           "Content"]])

      @request.should_receive(:inject_header_content)
      @request.should_receive(:endpoint_url)

      @response = double("response", code: 200, body: "response")
    end

    it "creates log message" do
      body = VBMS::Requests.soap { "body" }
      puts body
      allow(HTTPI).to receive(:post).and_return(@response)

      allow(@client).to receive(:process_response).and_return(nil)
      allow(@client).to receive(:wrap_in_soap).and_return(body.to_s)
      allow(@client).to receive(:encrypt).and_return(body.to_s)
      allow(@client).to receive(:create_body)
      allow(@client).to receive(:serialize_document).and_return(body.to_s)
      allow(@client).to receive(:process_body)

      expect(@client).to receive(:log).with(:request, response_code: @response.code,
                                                      request_body: body.to_s,
                                                      response_body: @response.body,
                                                      request: @request)

      @client.send_request(@request)
    end
  end

  describe "inject_header_content" do
    it "injects username and station id" do
      veteran_record = {
        file_number: "561349920",
        sex: "M",
        first_name: "Stan",
        last_name: "Stanman",
        ssn: "796164121",
        address_line1: "Shrek's Swamp",
        address_line2: "",
        address_line3: "",
        city: "Charleston",
        state: "SC",
        country: "USA",
        zip_code: "29401"
      }

      claim = {
        benefit_type_code: "1",
        payee_code: "00",
        station_of_jurisdiction: "317",
        end_product_code: "070CERT2AMC",
        end_product_modifier: "071",
        end_product_label: "AMC-Cert to BVA",
        predischarge: false,
        gulf_war_registry: false,
        date: 20.days.ago.to_date,
        suppress_acknowledgment_letter: false,
        limited_poa_code: "007",
        limited_poa_access: true
      }

      request = VBMS::Requests::EstablishClaim.new(veteran_record, claim, v5: true, send_userid: true)
      @client = new_test_client(css_id: "KLAYTHOMPSON", station_id: "415")

      doc = @client.inject_header_content(SoapScum::WSSecurity.encrypt(request.soap_doc, request.signed_elements), request)
      expect(doc.at_xpath("//ext:cssUserName", "ext" => "http://vbms.vba.va.gov/external").content).to eq("KLAYTHOMPSON")
      expect(doc.at_xpath("//ext:cssStationId", "ext" => "http://vbms.vba.va.gov/external").content).to eq("415")
      expect(doc.at_xpath("//ext:SecurityLevel", "ext" => "http://vbms.vba.va.gov/external").content).to eq("9")
    end
  end

  describe "process_response" do
    let(:request) { double("request", mtom_attachment?: false) }
    let(:response_body) { "" }
    let(:response) { double("response", body: response_body, headers: { "Content-Type" => "text/xml" }) }

    subject { @client.process_response(request, response) }

    context "when it is given valid encrypted XML" do
      pending("A sane crypto configuration, and re-encrypted files")
      let(:response_body) do
        encrypted_xml_file(
          fixture_path("requests/fetch_document.xml"),
          fixture_path("test_server.jks"),
          "fetchDocumentResponse"
        )
      end

      it "should return a decrypted XML document" do
        expect(request).to receive(:handle_response) do |doc|
          expect(doc).to be_a(Nokogiri::XML::Document)
          expect(doc.at_xpath("//soapenv:Envelope", VBMS::XML_NAMESPACES)).to_not be_nil
        end

        expect { subject }.to_not raise_error
      end
    end

    context "when it is given an unencrypted XML" do
      let(:response_body) { fixture_path("requests/fetch_document.xml") }

      it "should raise a SOAPError" do
        expect { subject }.to raise_error do |error|
          expect(error).to be_a(VBMS::SOAPError)
          expect(error.message).to eq("Unable to parse SOAP message")
          expect(error.body).to eq(response_body)
        end
      end
    end

    context "when it is given a document that won't decrypt" do
      let(:response_body) do
        encrypted_xml_file(
          fixture_path("requests/fetch_document.xml"),
          fixture_path("test_server.jks"),
          "fetchDocumentResponse"
        ).gsub(
          %r{<xenc:CipherValue>.+</xenc:CipherValue>},
          "<xenc:CipherValue></xenc:CipherValue>"
        )
      end

      it "should raise an OpenSSL error" do
        expect { subject }.to raise_error do |error|
          expect(error).to be_a(OpenSSL::PKey::RSAError)
        end
      end
    end

    context "when it is given a document that contains a SOAP fault" do
      let(:response_body) do
        <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Client</faultcode>
              <faultstring>Message does not have necessary info</faultstring>
              <faultactor>http://foo.com</faultactor>
              <detail>Detailed fault information</detail>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
        XML
      end

      it "should raise a SOAPError" do
        expect { subject }.to raise_error do |error|
          expect(error).to be_a(VBMS::SOAPError)
          expect(error.message).to eq("SOAP Fault returned")
          expect(error.body).to eq(response_body)
        end
      end
    end

    context "when it is given a document that does not have body" do
      let(:response_body) do
        <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
        </soap:Envelope>
        XML
      end

      it "should raise a SOAPError" do
        expect { subject }.to raise_error do |error|
          expect(error).to be_a(VBMS::SOAPError)
          expect(error.message).to eq("No SOAP body found in response")
          expect(error.body).to eq(response_body)
        end
      end
    end

    context "when the server sends an HTML response error page" do
      let(:response_body) do
        <<-XML
          <html><head><title>An error has occurred</title></head>
          <body><p>I know you were expecting HTML, but sometimes sites do this</p></body>
          </html>
        XML
      end

      it "should raise a SOAPError" do
        expect { subject }.to raise_error do |error|
          expect(error).to be_a(VBMS::SOAPError)
          expect(error.message).to eq("No SOAP envelope found in response")
          expect(error.body).to eq(response_body)
        end
      end
    end
  end
  describe "#build_request" do
    before do
      @client = new_test_client(use_forward_proxy: true)
    end

    subject { @client.build_request("https://some.fake.endpoint", {}, {}) }

    it "adds host header required by proxy" do
      expect(subject.headers["Host"]).to eq("test.endpoint.url/")
    end
  end
end
