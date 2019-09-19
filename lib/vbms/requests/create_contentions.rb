# frozen_string_literal: true

module VBMS
  module Requests
    class CreateContentions < BaseRequest
      include AddExtSecurityHeader

      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v4",
        "xmlns:cdm" => "http://vbms.vba.va.gov/cdm/claim/v4",
        "xmlns:participant" => "http://vbms.vba.va.gov/cdm/participant/v4"
      }.freeze

      NAMESPACES_V5 = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v5",
        "xmlns:cdm" => "http://vbms.vba.va.gov/cdm/claim/v5",
        "xmlns:participant" => "http://vbms.vba.va.gov/cdm/participant/v5"
      }.freeze

      # Contentions should be an array of objects representing the contention descriptions and special issues
      # [{description: "contention description", special_issues: [{ code: "SSR", narrative: "Same Station Review" }]}]
      def initialize(veteran_file_number:, claim_id:, contentions:, claim_date:, v5: false, send_userid: false)
        @veteran_file_number = veteran_file_number
        @claim_id = claim_id
        @contentions = contentions
        @v5 = v5
        @send_userid = send_userid
        @claim_date = claim_date
      end

      def name
        "createContentions"
      end

      def specify_endpoint
        @v5 ? :claimsv5 : :claims
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[specify_endpoint]}"
      end

      def soap_doc
        VBMS::Requests.soap(more_namespaces: @v5 ? NAMESPACES_V5 : NAMESPACES) do |xml|
          xml["cla"].createContentions do
            @contentions.each do |contention|
              xml["cla"].contentionsToCreate({
                # 0 means the id will be auto generated
                id: "0",

                # 0 means there is no parent contention
                secondaryToContentionID: "0",

                fileNumber: @veteran_file_number,
                claimId: @claim_id,
                title: contention[:description],

                actionableItem: "true",
                medical: "true",
                typeCode: "REP",
                workingContention: "YES",

                awaitingResponse: "unused. but required.",
                partcipantContention: "unused, but required."
              }.merge(original_contention_ids(contention))) do
                xml["cdm"].submitDate @claim_date.iso8601

                contention[:special_issues]&.each do |special_issue|
                  xml["cdm"].issue(
                    typeCd: special_issue[:code],
                    narrative: special_issue[:narrative],
                    inferred: "false"
                  )
                end

                xml["cdm"].origSrc "APP" if @v5
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
        if @v5
          doc.xpath(
            "//claimV5:createContentionsResponse/claimV5:createdContentions",
            VBMS::XML_NAMESPACES
          ).map do |xml|
            VBMS::Responses::Contention.create_from_xml(xml, key: :created_contentions)
          end
        else
          doc.xpath(
            "//claimV4:createContentionsResponse/claimV4:createdContentions",
            VBMS::XML_NAMESPACES
          ).map do |xml|
            VBMS::Responses::Contention.create_from_xml(xml, key: :created_contentions)
          end
        end
      end

      private

      def original_contention_ids(contention)
        return {} unless contention[:original_contention_ids]

        { "origContentionIds" => contention[:original_contention_ids].join(" ") }
      end
    end
  end
end
