# frozen_string_literal: true
describe VBMS::Requests::EstablishClaim do
  let(:veteran_record) do
    {
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
  end

  # NOTE: In order for this to pass when connected to VBMS
  # the information here cannot be a duplicate of an existing
  # claim. The easiest way to do this is to increment the `end_product_modifier`
  let(:claim) do
    {
      benefit_type_code: "1",
      payee_code: "00",
      station_of_jurisdiction: "317",
      end_product_code: "070CERT2AMC",
      end_product_modifier: "071",
      end_product_label: "AMC-Cert to BVA",
      predischarge: false,
      gulf_war_registry: false,
      date: 20.days.ago.to_date,
      suppress_acknowledgment_letter: false
    }
  end

  it "executes succesfully when pointed at VBMS" do
    request = VBMS::Requests::EstablishClaim.new(veteran_record, claim)

    webmock_soap_response("#{@client.base_url}#{VBMS::ENDPOINTS[:claims]}",
                          "establish_claim",
                          "establishedClaim")

    result = @client.send_request(request)

    expect(result.claim_id).to be_a_kind_of(String)
  end

  it "executes successfully including POA fields for v5" do
    v5_claim = claim.merge(
      limited_poa_code: "007",
      limited_poa_access: true
    )
    request = VBMS::Requests::EstablishClaim.new(veteran_record, v5_claim, v5: true)

    webmock_soap_response("#{@client.base_url}#{VBMS::ENDPOINTS[:claimsv5]}",
                          "establish_claim_v5",
                          "establishedClaim")

    result = @client.send_request(request)

    expect(result.claim_id).to be_a_kind_of(String)
    # this is a weak test
  end
end
