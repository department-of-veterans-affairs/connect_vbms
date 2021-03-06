# frozen_string_literal: true

# Return all the documents for a file_number.
# Iterates over all the pages to collect them in memory.

module VBMS
  module Service
    class PagedDocuments < Base
      def call(file_number:)
        documents = []
        req = next_request(file_number, 0)
        first_page = client.send_request(req)

        # interpret a first page with no sections (and no doc count) as equivalent to zero pages.
        raise ZeroPagesError.new("No sections found in first page") if first_page.empty?

        # response will always be an array. get pagination from the first section.
        (documents << first_page.map { |section| section[:documents] }).flatten!
        pagination = first_page.first[:paging]
        next_offset = pagination[:@next_start_index].to_i
        total_docs = pagination[:@total_result_count].to_i
        pages = 1

        # if we need to fetch more docs, iterate till we exhaust the pages
        while total_docs > documents.length && next_offset > 0
          next_page = client.send_request(next_request(file_number, next_offset))
          (documents << next_page.map { |section| section[:documents] }).flatten!
          next_offset = next_page.first[:paging][:@next_start_index].to_i
          pages += 1
        end

        { paging: pagination, pages: pages, documents: documents }
      end

      private

      def next_request(file_number, offset)
        VBMS::Requests::FindPagedDocumentSeriesReferences.new(file_number: file_number, offset: offset)
      end
    end
  end
end
