module VBMS
  module Requests
    class ListDocuments
      def initialize(file_number)
        @file_number = file_number
      end

      def name
        return "listDocuments"
      end

      def template()
        return VBMS.load_erb("list_documents_xml_template.xml.erb")
      end

      def render_xml()
        file_number = @file_number

        return self.template.result(binding)
      end

      def render_xml_noko
        VBMS::Requests.soap do |xml|
          xml['v4'].listDocuments {
            xml['v4'].fileNumber @file_number
          }
        end.to_xml
      end

      def is_multipart
        return false
      end

      def handle_response(doc)
        return doc.xpath(
          "//v4:listDocumentsResponse/v4:result", VBMS::XML_NAMESPACES
        ).map do |el|
          VBMS::Document.new(
            el["id"],
            el["filename"],
            el["docType"],
            el["source"],
            Time.parse(el.at_xpath(
              "//ns2:receivedDt/text()", VBMS::XML_NAMESPACES
            ).content).to_date,
          )
        end
      end
    end
  end
end
