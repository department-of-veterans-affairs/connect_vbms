module VBMS
  module Requests
    class GetDocumentTypes
      def name
        "getDocumentTypes"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["v4"].getDocumentTypes
        end
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def multipart?
        false
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
