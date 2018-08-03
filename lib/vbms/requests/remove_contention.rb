module VBMS
  module Requests
    class RemoveContention < BaseRequest
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

      def initialize(contention_id:, v5: false)
        @contention_id = contention_id
        @v5 = v5
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

      def inject_header_content(header_xml)
        Nokogiri::XML::Builder.with(header_xml) do |xml|
          xml["vbmsext"].userId("dslogon.1011239249", "xmlns:vbmsext" => "http://vbms.vba.va.gov/external")
        end
      end

      def namespaces
        @v5 ? NAMESPACES_V5 : NAMESPACES
      end

      def soap_doc
        puts
        VBMS::Requests.soap(more_namespaces: namespaces) do |xml|
          xml["cla"].removeContention do
            xml["cla"].contentionToRemove @contention_id
          end
        end
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(_doc)
        # At the moment, the response body only returns true. If we get here, no other errors will have been raised.
        # We just need a success status. :)
        true
      end
    end
  end
end
