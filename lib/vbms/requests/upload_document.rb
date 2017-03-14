# frozen_string_literal: true
module VBMS
  module Requests
    # This call operates in a two-phase approach. To upload a document,
    # call initializeUpload with metadata to receive a token used in the second call, uploadDocument
    # This service replaces UploadDocumentWithAssociation in eDocument Service v4, which is deprecated as of March 2017
    class UploadDocument < BaseRequest
      def initialize(upload_token:, filepath:)
        @upload_token = upload_token
        @filepath = filepath
      end

      def name
        "uploadDocument"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:upload]}"
      end

      def soap_doc
        # TODO: convert to using MTOM
        content = Base64.encode64(File.read(@filepath))
        document = VBMS::Requests.soap do |xml|
          xml["upload"].uploadDocument do
            xml.content content
            xml.uploadToken @upload_token
          end
        end
        # in Nokogiri, children inherit their parents' namespace
        # eFolder Service Version 1.0 in InitializeUpload, does not expect
        # namespaces inside the 'uploadDocument' element
        XMLHelper.remove_namespaces(document.at_xpath("//upload:uploadDocument").children)
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
        el = doc.xpath("//upload:uploadDocumentResponse", VBMS::XML_NAMESPACES).to_xml
        XMLHelper.convert_to_hash(el)
      end
    end
  end
end
