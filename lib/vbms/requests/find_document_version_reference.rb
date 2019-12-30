# frozen_string_literal: true

module VBMS
  module Requests
    # This call returns a list of document version references matching the search criteria.
    class FindDocumentVersionReference < FindDocumentSeriesReference
      def name
        "findDocumentVersionReference"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["read"].findDocumentVersionReference do
            xml["read"].criteria do
              xml["v5"].veteran(
                "fileNumber" => @file_number
              )
            end
          end
        end
      end

      def handle_response(doc)
        doc.xpath(
          "//read:findDocumentVersionReferenceResponse/read:result", VBMS::XML_NAMESPACES
        ).map do |el|
          construct_response(XMLHelper.convert_to_hash(el.to_xml)[:result])
        end
      end
    end
  end
end
