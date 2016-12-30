module VBMS
  module Requests
    # Abstract class providing defaults to some of the methods requried
    class BaseRequest
      def inject_header_content(xml)
        xml
      end
    end
  end
end
