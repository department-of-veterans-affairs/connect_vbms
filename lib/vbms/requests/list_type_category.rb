# frozen_string_literal: true

module VBMS
  module Requests
    # This call returns a list of document types in VBMS
    # This service replaces getDocumentTypes in eDocument Service v4, which is deprecated as of March 2017
    class ListTypeCategory < BaseRequest
      def name
        "listTypeCategory"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["read"].listTypeCategory
        end
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:read]}"
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(doc)
        doc.xpath(
          "//read:listTypeCategoryResponse/read:result", VBMS::XML_NAMESPACES
        ).map do |el|
          construct_response(XMLHelper.convert_to_hash(el.to_xml)[:result])
        end
      end

      private

      def construct_response(result)
        OpenStruct.new(type_id: result[:@type_id], description: result[:@type_description_text])
      end
    end
  end
end
