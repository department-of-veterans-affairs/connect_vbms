# frozen_string_literal: true

module VBMS
  module Requests
    # This call returns a list of document version references matching the veteran and date range
    class FindDocumentVersionReferenceByDateRange < FindDocumentVersionReference
      def initialize(file_number:, begin_date_range:, end_date_range:)
        super(file_number)
        @begin = begin_date_range.to_datetime
        @end = end_date_range.to_datetime
      end

      def name
        "findDocumentVersionReferenceByDateRange"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["read"].findDocumentVersionReference do
            xml["read"].criteria do
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
    end
  end
end
