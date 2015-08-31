module VBMS
  module Requests
    class GetDocumentTypes
      def name
        'getDocumentTypes'
      end

      def render_xml
        VBMS::Requests.soap do |xml|
          xml['v4'].getDocumentTypes
        end
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
