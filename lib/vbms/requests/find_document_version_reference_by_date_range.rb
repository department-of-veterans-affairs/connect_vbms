# frozen_string_literal: true

module VBMS
    module Requests
        # This call returns a list of document version references matching the veteran and date range
        class FindDocumentVersionReferenceByDateRange
            def initialize(file_number:, begin_date_range:, end_date_range:)
                @file_number = file_number
                @begin = begin_date_range
                @end = end_date_range
            end

            def name
                "findDocumentVersionReferenceByDateRange"
            end

            def endpoint_url(base_url)
                "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:read]}"
            end

            def soap_doc
                VBMS::Requests.soap do |xml|
                    xml["read"].findDocumentVersionReference do
                        xml["read"].citeria do
                            xml["v5"].veteran(
                                "fileNumber" => @file_number
                            )
                            xml["v5"].vbmsUploadDate(
                                "begin" => @begin,
                                "end" => @end
                            )
                        end
                    end                    
                end  
            end

            def handle_response(doc)
                doc.xpath(
                  "//read:findDocumentVersionReferenceResponse/read:result", VBMS::XML_NAMESPACES
                ).map do |el|
                  construct_response(XMLHelper.convert_to_hash(el.to_xml)[:result])
                end
            end
        end
    end
end



