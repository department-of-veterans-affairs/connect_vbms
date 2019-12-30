# frozen_string_literal: true

module VBMS
  module Requests
    class ListContentions < BaseRequest
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

      def initialize(claim_id, v5: false)
        @claim_id = claim_id
        @v5 = v5
      end

      def name
        "listContentions"
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

      # More information on what the fields mean, see:
      # https://github.com/department-of-veterans-affairs/dsva-vbms/issues/66#issuecomment-266098034
      def soap_doc
        VBMS::Requests.soap(more_namespaces: namespaces) do |xml|
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
        if @v5
          doc.xpath(
            "//claimV5:listContentionsResponse/claimV5:listOfContentions",
            VBMS::XML_NAMESPACES
          ).map do |xml|
            VBMS::Responses::Contention.create_from_xml(xml)
          end
        else
          doc.xpath(
            "//claimV4:listContentionsResponse/claimV4:listOfContentions",
            VBMS::XML_NAMESPACES
          ).map do |xml|
            VBMS::Responses::Contention.create_from_xml(xml)
          end
        end
      end
    end
  end
end
