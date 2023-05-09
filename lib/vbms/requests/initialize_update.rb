# frozen_string_literal: true

module VBMS
  module Requests
    # Call this service with metadata to receive a token used in the second call, updateDocument
    class InitializeUpdate < BaseRequest
      def initialize(content_hash:, document_version_reference_id:, va_receive_date:, subject:)
        super()
        @content_hash = content_hash
        @document_version_reference_id = document_version_reference_id
        @va_receive_date = va_receive_date
        @subject = subject
      end

      def name
        "initializeUpdate"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:upload]}"
      end

      def va_receive_date
        @va_receive_date.getlocal("-05:00").strftime("%Y-%m-%d-05:00")
      end

      def soap_doc
        document = VBMS::Requests.soap do |xml|
          xml["update"].initializeUpdate do
            xml.documentVersionReferenceId @
            xml.contentHash @content_hash
            xml.vaReceiveDate va_receive_date
            xml.versionMetadata(key: "subject") do
              xml["v5"].value @subject
            end
          end
        end

        XMLHelper.remove_namespaces(document.at_xpath("//upload:initializeUpdate").children)
        document
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(doc)
        el = doc.at_xpath("//upload:initializeUpdateResponse", VBMS::XML_NAMESPACES).to_xml

        OpenStruct.new(upload_token: XMLHelper.convert_to_hash(el)[:initialize_update_response][:upload_token])
      end
    end
  end
end
