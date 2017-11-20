module VBMS
  module Requests
    class CreateContentions < BaseRequest
      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v4",
        "xmlns:cdm" => "http://vbms.vba.va.gov/cdm/claim/v4",
        "xmlns:participant" => "http://vbms.vba.va.gov/cdm/participant/v4"
      }.freeze

      # Contentions should be an array of strings representing the contentions
      def initialize(veteran_file_number:, claim_id:, contentions:)
        @veteran_file_number = veteran_file_number
        @claim_id = claim_id
        @contentions = contentions
      end

      def name
        "createContentions"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:claims]}"
      end

      def inject_header_content(header_xml)
        Nokogiri::XML::Builder.with(header_xml) do |xml|
          xml["vbmsext"].userId("dslogon.1011239249", "xmlns:vbmsext" => "http://vbms.vba.va.gov/external")
        end
      end

      def soap_doc
        VBMS::Requests.soap(more_namespaces: NAMESPACES) do |xml|
          xml["cla"].createContentions do
            @contentions.each do |contention_text|
              xml["cla"].contentionsToCreate(
                # 0 means the id will be auto generated
                id: "0",

                # 0 means there is no parent contention
                secondaryToContentionID: "0",

                fileNumber: @veteran_file_number,
                claimId: @claim_id,
                title: contention_text,

                actionableItem: "true",
                medical: "false",
                typeCode: "NEW",
                workingContention: "YES",

                awaitingResponse: "unused. but requrired.",
                partcipantContention: "unused, but required."
              ) do
                xml["cdm"].submitDate Date.today.iso8601
              end
            end
          end
        end
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(doc)
        doc.xpath(
          "//claimV4:createContentionsResponse/claimV4:createdContentions",
          VBMS::XML_NAMESPACES
        ).map do |xml|
          VBMS::Responses::Contention.create_from_xml(xml)
        end
      end
    end
  end
end
