module VBMS
  module Requests
    class GetDocumentTypes
      def name
        return "getDocumentTypes"
      end

      def render_xml
        return VBMS.load_erb("get_document_types_xml_template.xml.erb").result(binding)
      end

      def render_xml_noko
        VBMS::Requests.soap do |xml|
          xml['v4'].getDocumentTypes
        end
      end

      def is_multipart
        return false
      end

      def handle_response(doc)
        return doc.xpath("//v4:getDocumentTypesResponse/v4:result", VBMS::XML_NAMESPACES).map do |el|
          DocumentType.new(
            el["id"],
            el["description"]
          )
        end
      end
    end
  end
end
