module VBMS
  module Requests
    class GetDocumentTypes < BaseRequest
      def name
        "getDocumentTypes"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["v4"].getDocumentTypes
        end
      end

      def inject_header_content(xml)
        xml
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder]}"
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(doc)
        doc.xpath(
          "//v4:getDocumentTypesResponse/v4:result", VBMS::XML_NAMESPACES
        ).map do |el|
          VBMS::Responses::DocumentType.create_from_xml(el)
        end
      end
    end
  end
end
