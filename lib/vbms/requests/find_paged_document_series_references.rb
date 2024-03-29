# frozen_string_literal: true

module VBMS
  module Requests
    # This call returns a list of DocumentSeries objects containing the metadata
    # for documents that match search criteria.
    class FindPagedDocumentSeriesReferences < BaseRequest
      def initialize(file_number:, page_size: 3000, offset: 0)
        super()
        @file_number = file_number
        @page_size = page_size
        @offset = offset
      end

      def name
        "findPagedDocumentSeriesReferences"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:read]}"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["read"].findPagedDocumentSeriesReferences do
            xml["read"].searchCriteria do
              xml["v5"].veteran(
                "fileNumber" => @file_number
              )
            end
            xml["read"].pagingCriteria do
              xml["v5"].pageSize @page_size
              xml["v5"].startIndex @offset
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
          "//read:findPagedDocumentSeriesReferencesResponse/read:result", VBMS::XML_NAMESPACES
        ).map do |el|
          result = XMLHelper.convert_to_hash(el.to_xml)[:result]
          document_references = result[:document_series_references]
          paging = result[:paging_reference]
          documents = XMLHelper.versions_as_array(document_references).compact.map do |doc_ref|
            XMLHelper.versions_as_array(doc_ref[:versions]).map do |versions|
              construct_response(versions)
            end
          end || []
          { paging: paging, documents: documents.flatten }
        end
      end

      private

      def construct_response(versions)
        alt_doc_types = XMLHelper.find_hash_by_key(versions[:metadata], "altDocType")
        restricted = XMLHelper.find_hash_by_key(versions[:metadata], "restricted")
        OpenStruct.new(
          document_id: versions[:@document_version_ref_id],
          series_id: versions[:@document_series_ref_id],
          version: versions[:version][:@major],
          type_description: type_description(versions),
          type_id: type_id(versions),
          doc_type: type_id(versions),
          subject: versions[:@subject],
          received_at: versions[:va_receive_date],
          source: source(versions),
          mime_type: versions[:@mime_type],
          alt_doc_types: alt_doc_types.present? ? JSON.parse(alt_doc_types[:value]) : nil,
          restricted: restricted.present? ? restricted[:value] : nil,
          upload_date: versions[:vbms_upload_date]
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
