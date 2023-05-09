# frozen_string_literal: true

module VBMS
  module Requests
    # This call operates in a two-phase approach. To update a document,
    # call initializeUpdate with metadata to receive a token used in the second call, updateDocument
    class UpdateDocument < BaseRequest
      def initialize(upload_token:, filepath:)
        super()
        @upload_token = upload_token
        @filepath = filepath
      end

      def name
        "updateDocument"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:upload]}"
      end

      def soap_doc
        # TODO: convert to using MTOM
        content = Base64.encode64(File.read(@filepath))
        document = VBMS::Requests.soap do |xml|
          xml["update"].uploadDocument do
            xml.content content
            xml.uploadToken @upload_token
          end
        end

        XMLHelper.remove_namespaces(document.at_xpath("//upload:updateDocument").children)
        document
      end

      # Double encryption must not be used on operations uploadDocument and updateDocument
      def signed_elements
        []
      end

      # TODO: convert to using MTOM
      def multipart?
        false
      end

      def multipart_file
        @filepath
      end

      def handle_response(doc)
        el = doc.xpath("//upload:updateDocumentResponse", VBMS::XML_NAMESPACES).to_xml
        OpenStruct.new(XMLHelper.convert_to_hash(el))
      end
    end
  end
end
