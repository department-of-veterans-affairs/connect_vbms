module VBMS
  module Requests
    # This call returns a list of DocumentSeries objects containing the metadata
    # for documents that match search criteria.
    # It maps to listDocuments in eDocument Service v4 (deprecated)
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
          xml["efol"].findDocumentSeriesReference do
            xml["efol"].criteria do
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
          "//efol:findDocumentSeriesReferenceResponse/efol:result", VBMS::XML_NAMESPACES
        ).map do |el|
          constuct_response(XMLHelper.convert_to_hash(el.to_xml)[:result])
        end
      end

      private

      def constuct_response(result)
        version = XMLHelper.most_recent_version(result[:versions])
        alt_doc_types = XMLHelper.extract_value(version[:metadata], "altDocType")
        restricted = XMLHelper.extract_value(version[:metadata], "restricted")
        {
          document_id: version[:@document_version_ref_id],
          type_description: version[:type_category][:@type_description_text],
          type_id: version[:type_category][:@type_id],
          va_receive_date: version[:va_receive_date],
          source: version[:source][:@source_name],
          mime_type: version[:@mime_type],
          alt_doc_types: alt_doc_types.present? ? JSON.parse(alt_doc_types[:value]) : nil,
          restricted: restricted.present? ? restricted[:value] : nil
        }
      end
    end
  end
end