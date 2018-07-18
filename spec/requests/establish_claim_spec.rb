# frozen_string_literal: true
describe VBMS::Requests::EstablishClaim do
  let(:request) do
    VBMS::Requests::EstablishClaim.new(
      veteran_record: {:sex=>"M",
        :first_name=>"eight",
        :last_name=>"hardy",
        :ssn=>"888451278",
        :address_line1=>"2122 W TAYLOR ST",
        :address_line2=>nil,
        :address_line3=>nil,
        :city=>"CHICAGO",
        :state=>"IL",
        :country=>"USA",
        :zip_code=>"60612",
        :service=>[
          {
            :short_service_number=>nil,
            :service_number_fill=>nil,
            :branch_of_service=>"AF  ",
            :entered_on_duty_date=>"01011990",
            :released_active_duty_date=>"01011995",
            :separation_reason_code=>"SAT",
            :nonpay_days=>nil,
            :pay_grade=>nil,
            :char_of_svc_code=>"HON"
          },
          {:short_service_number=>nil,
            :service_number_fill=>nil,
            :branch_of_service=>nil,
            :entered_on_duty_date=>nil,
            :released_active_duty_date=>nil,
            :separation_reason_code=>nil,
            :nonpay_days=>nil,
            :pay_grade=>nil,
            :char_of_svc_code=>nil
          },
          {
            :short_service_number=>nil,
            :service_number_fill=>nil,
            :branch_of_service=>nil,
            :entered_on_duty_date=>nil,
            :released_active_duty_date=>nil,
            :separation_reason_code=>nil,
            :nonpay_days=>nil,
            :pay_grade=>nil,
            :char_of_svc_code=>nil
            }
          ],
          :date_of_birth=>"01/01/1970",
          :file_number=>"888451278",
          :address_type=>""
        },
      claim: {
        :benefit_type_code=>"1",
        :payee_code=>"00",
        :predischarge=>false,
        :claim_type=>"Claim",
        :end_product_modifier=>"032",
        :end_product_code=>"030HLRR",
        :end_product_label=>"Higher Level Review Rating",
        :station_of_jurisdiction=>"397",
        :date=>2.days.ago.to_date,
        :suppress_acknowledgement_letter=>false,
        :gulf_war_registry=>false,
        :claimant_participant_id=>"600199585"
      }
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
    let(:doc) { parse_strict(fixture("responses/establish_claim.xml")) }
    subject { request.handle_response(doc) }

    it "should return a claim" do
      puts subject
      expect(subject).to be_a(String)
      expect(subject).to eq("1234")
    end
  end
end
