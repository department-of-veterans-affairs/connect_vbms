module VBMS
  module Requests
    class ListDocuments
      def initialize(file_number)
        @file_number = file_number
      end

      def name
        'listDocuments'
      end

      def template
        VBMS.load_erb('list_documents_xml_template.xml.erb')
      end

      def render_xml
        VBMS::Requests.soap do |xml|
          xml['v4'].listDocuments do
            xml['v4'].fileNumber @file_number
          end
        end
      end

      def multipart?
        false
      end

      def handle_response(doc)
        doc.xpath(
          '//v4:listDocumentsResponse/v4:result', VBMS::XML_NAMESPACES
        ).map do |el|
          VBMS::Responses::Document.create_from_xml(el)
        end
      end
    end
  end
end
