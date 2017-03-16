# frozen_string_literal: true
module VBMS
  module Requests
    # Call this service with metadata to receive a token used in the second call, uploadDocument
    class InitializeUpload < BaseRequest
      def initialize(content_hash:, filename:, file_number:, va_receive_date:, doc_type:, source:, subject:, new_mail:)
        @content_hash = content_hash
        @filename = filename
        @file_number = file_number
        @va_receive_date = va_receive_date
        @doc_type = doc_type
        @source = source
        @subject = subject
        @new_mail = new_mail
      end

      def name
        "initializeUpload"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:upload]}"
      end

      # EST is used because that's what VBMS used in
      # their sample SoapUI projects.
      def va_receive_date
        @va_receive_date.getlocal("-05:00").strftime("%Y-%m-%d-05:00")
      end

      def soap_doc
        document = VBMS::Requests.soap do |xml|
          xml["upload"].initializeUpload do
            xml.fileName @filename
            xml.contentHash @content_hash
            xml.docType @doc_type
            xml.source @source
            xml.vaReceiveDate va_receive_date
            xml.veteranIdentifier(fileNumber: @file_number)
            xml.versionMetadata(key: "subject") do
              xml["v5"].value @subject
            end
            xml.versionMetadata(key: "newMail") do
              xml["v5"].value @new_mail
            end
          end
        end
        # in Nokogiri, children inherit their parents' namespace
        # eFolder Service Version 1.0 in InitializeUpload, does not expect
        # namespaces inside the 'initializeUpload' element
        XMLHelper.remove_namespaces(document.at_xpath("//upload:initializeUpload").children)
        document
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(doc)
        el = doc.at_xpath("//upload:initializeUploadResponse", VBMS::XML_NAMESPACES).to_xml
        OpenStruct.new(upload_token: XMLHelper.convert_to_hash(el)[:initialize_upload_response][:upload_token])
      end
    end
  end
end
