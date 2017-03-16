# frozen_string_literal: true
module VBMS
  module Requests
    # This call returns a list of DocumentSeries objects containing the metadata
    # for documents that match search criteria.
    # This service replaces listDocuments in eDocument Service v4, which is deprecated as of March 2017
    class FindDocumentSeriesReference < BaseRequest
      def initialize(file_number)
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
          construct_response(XMLHelper.convert_to_hash(el.to_xml)[:result])
        end
      end

      private

      def construct_response(result)
        version = XMLHelper.most_recent_version(result[:versions])
        alt_doc_types = XMLHelper.find_hash_by_key(version[:metadata], "altDocType")
        restricted = XMLHelper.find_hash_by_key(version[:metadata], "restricted")
        OpenStruct.new(
          document_id: version[:@document_version_ref_id],
          type_description: type_description(version),
          type_id: type_id(version),
          doc_type: type_id(version),
          received_at: version[:va_receive_date],
          source: source(version),
          mime_type: version[:@mime_type],
          alt_doc_types: alt_doc_types.present? ? JSON.parse(alt_doc_types[:value]) : nil,
          restricted: restricted.present? ? restricted[:value] : nil
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
