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
          received_date = el.at_xpath(
            'ns2:receivedDt/text()', VBMS::XML_NAMESPACES
          )
          VBMS::Document.new(
            el['id'],
            el['filename'],
            el['docType'],
            el['source'],
            received_date.nil? ? nil : Time.parse(received_date.content).to_date
          )
        end
      end
    end
  end
end
