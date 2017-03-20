module VBMS
  module Requests
    # Abstract class providing defaults to some of the methods requried
    class BaseRequest
      def multipart?
        false
      end

      def mime_attachment?
        false
      end

      def inject_header_content(xml)
        xml
      end
    end
  end
end
