module VBMS
  module Requests
    class GetDispositions < BaseRequest
      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v5"
      }.freeze

      def initialize(claim_id:)
        @claim_id = claim_id
      end

      def name
        "getDispositions"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:claimsv5]}"
      end

      def soap_doc
        VBMS::Requests.soap(more_namespaces: NAMESPACES) do |xml|
          xml["cla"].getDispositions do
            xml["cla"].claimId @claim_id
          end
        end
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(_doc)
        doc.at_xpath(
          "//claimV5:getDispositionsResponse/claimV5:dispositionAssociations",
          VBMS::XML_NAMESPACES
        ).map do |el|
          VBMS::Responses::Disposition.create_from_xml(el)
        end
      end
    end
  end
end
