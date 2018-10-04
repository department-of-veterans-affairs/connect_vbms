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
      suppress_acknowledgment_letter: false,
      limited_poa_code: "007",
      limited_poa_access: true
    }
  end

  context "#soap_doc" do
    it "includes conditional fields for v5" do
      v4_request = VBMS::Requests::EstablishClaim.new(veteran_record, claim, v5: false)
      v4_soap_doc = v4_request.soap_doc.to_s
      expect(v4_soap_doc).not_to match('limitedPoaCode="007"')
      expect(v4_soap_doc).not_to match('limitedPoaAccess="true"')

      v5_request = VBMS::Requests::EstablishClaim.new(veteran_record, claim, v5: true)
      v5_soap_doc = v5_request.soap_doc.to_s
      expect(v5_soap_doc).to match('limitedPoaCode="007"')
      expect(v5_soap_doc).to match('limitedPoaAccess="true"')
    end
  end
end
