# frozen_string_literal: true

module VBMS
  module Requests
    class GetDispositions < BaseRequest
      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v5"
      }.freeze

      def initialize(claim_id:)
        super()
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

      def handle_response(doc)
        doc.at_xpath(
          "//claimV5:getDispositionsResponse",
          VBMS::XML_NAMESPACES
        ).elements.map do |el|
          VBMS::Responses::Disposition.create_from_xml(el.attributes)
        end
      end
    end
  end
end
