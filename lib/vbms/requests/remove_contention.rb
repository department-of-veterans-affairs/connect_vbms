module VBMS
  module Requests
    class RemoveContention < BaseRequest
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
        @contention = contention
        @v5 = v5
        @send_userid = send_userid
      end

      def name
        "removeContention"
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
          xml["cla"].removeContention do
            xml["cla"].contentionToRemove(
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
              xml["cdm"].startDate @contention[:start_date]
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
        # returns "true" if successful at removing contention
        el = if @v5
               doc.at_xpath(
                 "//claimV5:removeContentionResponse/claimV5:wasContentionRemoved",
                 VBMS::XML_NAMESPACES
               )
             else
               doc.at_xpath(
                 "//claimV4:removeContentionResponse/claimV4:wasContentionRemoved",
                 VBMS::XML_NAMESPACES
               )
             end
        el.text
      end
    end
  end
end
