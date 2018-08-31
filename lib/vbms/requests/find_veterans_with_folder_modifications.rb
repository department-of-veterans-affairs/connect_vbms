# frozen_string_literal: true
module VBMS
  module Requests
    # This call returns a list of fileNumbers for all Veterans who have new documents of
    # type typeId in their eFolder from dateFrom to dateTo.
    class FindVeteransWithFolderModifications < BaseRequest
      def initialize(typeId:, dateFrom:, dateTo:)
        @typeId = typeId
        @dateFrom = dateFrom
        @dateTo = dateTo
      end

      def name
        "findVeteransWithFolderModifications"
      end

      def endpoint_url(base_url)
        "#{base_url}#{VBMS::ENDPOINTS[:efolder_svc_v1][:read]}"
      end

      def soap_doc
        VBMS::Requests.soap do |xml|
          xml["read"].findVeteransWithFolderModifications do
            xml["read"].criteria do
              xml["v5"].dateTimeRange(
                "from" => @dateFrom.iso8601,
                "to" => @dateTo.iso8601
              )
              xml["v5"].typeCategory(
                "typeId" => @typeId
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
          "//read:findVeteransWithFolderModificationsResponse/read:result", VBMS::XML_NAMESPACES
        ).map do |el|
          XMLHelper.convert_to_hash(el.to_xml)[:result][:@file_number]
        end
      end
    end
  end
end
