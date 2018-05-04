# frozen_string_literal: true
module VBMS
  module Requests
    # This call gets the binary document content for a specific Document Version
    # This service replaces FetchDocumentById in eDocument Service v4, which is deprecated as of March 2017
    class GetDocumentContent < BaseRequest
      attr_accessor :mtom_attachment

      def initialize(document_id)
        @document_id = document_id
      end

      def name
        "getDocumentContent"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:read]}"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["read"].getDocumentContent do
            xml["read"].documentVersionRefID @document_id
          end
        end
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(doc)
        begin 
          el = doc.at_xpath(
            "//read:getDocumentContentResponse/read:result", VBMS::XML_NAMESPACES
          )
          construct_response(XMLHelper.convert_to_hash(el.to_xml)[:result])
        rescue NoMethodError
          raise SOAPError.new("No SOAP body results found in response")
        end
      end

      def mtom_attachment?
        true
      end

      private

      def construct_response(result)
        OpenStruct.new(
          document_id: result[:@document_version_reference_id],
          content: mtom_attachment
        )
      end
    end
  end
end
