# frozen_string_literal: true

module VBMS
  module Requests
    class UpdateContention < BaseRequest
      include AddExtSecurityHeader

      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v4",
        "xmlns:cdm" => "http://vbms.vba.va.gov/cdm/claim/v4",
        "xmlns:common" => "http://vbms.vba.va.gov/cdm/common/v4"
      }.freeze

      NAMESPACES_V5 = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v5",
        "xmlns:cdm" => "http://vbms.vba.va.gov/cdm/claim/v5",
        "xmlns:comon" => "http://vbms.vba.va.gov/cdm/comon/v5"
      }.freeze

      def initialize(contention:, v5: false, send_userid: false)
        super()
        @contention = contention
        @v5 = v5
        @send_userid = send_userid
      end

      def name
        "updateContention"
      end

      def specify_endpoint
        @v5 ? :claimsv5 : :claims
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[specify_endpoint]}"
      end

      def namespaces
        @v5 ? NAMESPACES_V5 : NAMESPACES
      end

      def soap_doc
        VBMS::Requests.soap(more_namespaces: namespaces) do |xml|
          xml["cla"].updateContention do
            xml["cla"].contentionToBeUpdated(
              "id" => @contention[:id],
              "actionableItem" => @contention[:actionable_item],
              "awaitingResponse" => @contention[:awaiting_response], # required
              "claimId" => @contention[:claim_id],
              "classificationCd" => @contention[:classification_cd],
              "fileNumber" => @contention[:file_number],
              "levelStatusCode" => @contention[:level_status_code],
              "medical" => @contention[:medical],
              "partcipantContention" => @contention[:participant_contention], # required
              "secondaryToContentionID" => @contention[:secondary_to_contention_id], # required
              "title" => @contention[:text], # required
              "typeCode" => @contention[:type_code], # required
              "workingContention" => @contention[:working_contention] # required
            ) do
              xml["cdm"].submitDate @contention[:submit_date]

              @contention[:special_issues]&.each do |special_issue|
                xml["cdm"].issue(
                  typeCd: special_issue[:code],
                  narrative: special_issue[:narrative],
                  inferred: special_issue[:inferred],
                  id: special_issue[:id],
                  contentionId: special_issue[:contention_id],
                  specificRating: special_issue[:specific_rating]
                )
              end

              xml["cdm"].startDate @contention[:start_date]
              xml["cdm"].origSrc "APP" if @v5
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
        xml = if @v5
                doc.xpath(
                  "//claimV5:updateContentionResponse/claimV5:updatedContention",
                  VBMS::XML_NAMESPACES
                )
              else
                doc.xpath(
                  "//claimV4:updateContentionResponse/claimV4:updatedContention",
                  VBMS::XML_NAMESPACES
                )
              end

        VBMS::Responses::Contention.create_from_xml(xml, key: :updated_contention)
      end
    end
  end
end
