module VBMS
  module Requests
    class ListDocuments < BaseRequest
      def initialize(file_number)
        @file_number = file_number
      end

      def name
        "listDocuments"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder]}"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["v4"].listDocuments do
            xml["v4"].fileNumber @file_number
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
          "//v4:listDocumentsResponse/v4:result", VBMS::XML_NAMESPACES
        ).map do |el|
          VBMS::Responses::Document.create_from_xml(el)
        end
      end
    end
  end
end
