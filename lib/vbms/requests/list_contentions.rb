module VBMS
  module Requests
    class ListContentions < BaseRequest
      NAMESPACES = {
        "xmlns:cla" => "http://vbms.vba.va.gov/external/ClaimService/v4",
        "xmlns:cdm" => "http://vbms.vba.va.gov/cdm/claim/v4",
        "xmlns:participant" => "http://vbms.vba.va.gov/cdm/participant/v4"
      }.freeze

      def initialize(claim_id)
        @claim_id = claim_id
      end

      def name
        "listContentions"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:claims]}"
      end

      def inject_header_content(header_xml)
        Nokogiri::XML::Builder.with(header_xml) do |xml|
          xml["vbmsext"].userId("dslogon.1011239249", "xmlns:vbmsext" => "http://vbms.vba.va.gov/external")
        end
      end

      # More information on what the fields mean, see:
      # https://github.com/department-of-veterans-affairs/dsva-vbms/issues/66#issuecomment-266098034
      def soap_doc
        VBMS::Requests.soap(more_namespaces: NAMESPACES) do |xml|
          xml["cla"].listContentions do
            xml["cla"].claimIdForListContentions @claim_id
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
          "//claimV4:listContentionsResponse/claimV4:listOfContentions",
          VBMS::XML_NAMESPACES
        ).map do |xml|
          VBMS::Responses::Contention.create_from_xml(xml)
        end
      rescue NoMethodError
        raise SOAPError.new("No listOfContentions found in SOAP response")
      end
    end
  end
end
