# frozen_string_literal: true

module VBMS
  module Requests
    # This call returns a list of DocumentSeries objects containing the metadata
    # for documents that match search criteria.
    class FindDocumentSeriesReference < BaseRequest
      def initialize(file_number)
        super()
        @file_number = file_number
      end

      def name
        "findDocumentSeriesReference"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:read]}"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["read"].findDocumentSeriesReference do
            xml["read"].criteria do
              xml["v5"].veteran(
                "fileNumber" => @file_number
              )
            end
          end
        end
      end

      def signed_elements
        [["/soapenv:Envelope/soapenv:Body",
          { soapenv: SoapScum::XMLNamespaces::SOAPENV },
          "Content"]]
      end

      def handle_response(doc)
        doc.xpath(
          "//read:findDocumentSeriesReferenceResponse/read:result", VBMS::XML_NAMESPACES
        ).map do |el|
          result = XMLHelper.convert_to_hash(el.to_xml)[:result]
          XMLHelper.versions_as_array(result[:versions]).map do |version|
            construct_response(version)
          end
        end
      end

      private

      def construct_response(result)
        alt_doc_types = XMLHelper.find_hash_by_key(result[:metadata], "altDocType")
        restricted = XMLHelper.find_hash_by_key(result[:metadata], "restricted")
        OpenStruct.new(
          document_id: result[:@document_version_ref_id],
          series_id: result[:@document_series_ref_id],
          version: result[:version][:@major],
          type_description: type_description(result),
          type_id: type_id(result),
          doc_type: type_id(result),
          subject: result[:@subject],
          received_at: result[:va_receive_date],
          source: source(result),
          mime_type: result[:@mime_type],
          alt_doc_types: alt_doc_types.present? ? JSON.parse(alt_doc_types[:value]) : nil,
          restricted: restricted.present? ? restricted[:value] : nil,
          upload_date: result[:vbms_upload_date]
        )
      end

      def type_description(version)
        version[:type_category].present? ? version[:type_category][:@type_description_text] : nil
      end

      def type_id(version)
        version[:type_category].present? ? version[:type_category][:@type_id] : nil
      end

      def source(version)
        version[:source].present? ? version[:source][:@source_name] : nil
      end
    end
  end
end
