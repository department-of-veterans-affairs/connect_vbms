module VBMS
  module Requests
    class FetchDocumentById
      def initialize(document_id)
        @document_id = document_id
      end

      def name
        return "fetchDocumentById"
      end

      def template()
        return VBMS.load_erb("fetch_document_by_id_xml_template.xml.erb")
      end

      def render_xml()
        document_id = @document_id

        return self.template.result(binding)
      end

      def render_xml_noko
        VBMS::Requests.soap do |xml|
          xml['v4'].fetchDocumentById {
            xml['v4'].documentId @document_id
          }
        end
      end

      def is_multipart
        return false
      end

      def handle_response(doc)
        el = doc.at_xpath(
          "//v4:fetchDocumentResponse/v4:result", VBMS::XML_NAMESPACES
        )
        document_el = el.at_xpath(
          "//v4:document", VBMS::XML_NAMESPACES
        )
        received_date = document_el.at_xpath(
          "//ns2:receivedDt/text()", VBMS::XML_NAMESPACES
        )
        return VBMS::DocumentWithContent.new(
          VBMS::Document.new(
            document_el["id"],
            document_el["filename"],
            document_el["docType"],
            document_el["source"],
            received_date.nil? ? nil : Time.parse(received_date.content).to_date,
          ),
          Base64.decode64(el.at_xpath(
            "//v4:content/ns2:data/text()", VBMS::XML_NAMESPACES
          ).content),
        )
      end
    end
  end
end
