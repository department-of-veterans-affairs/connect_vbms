module VBMS
  module Requests
    class GetDocumentTypes
      def name
        'getDocumentTypes'
      end

      def render_xml
        VBMS.load_erb('get_document_types_xml_template.xml.erb').result(binding)
      end

      def multipart?
        false
      end

      def handle_response(doc)
        doc.xpath(
          '//v4:getDocumentTypesResponse/v4:result', VBMS::XML_NAMESPACES
        ).map do |el|
          DocumentType.new(
            el['id'],
            el['description']
          )
        end
      end
    end
  end
end
