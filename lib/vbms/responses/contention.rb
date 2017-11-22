module VBMS
  module Responses
    class Contention < OpenStruct
      def self.create_from_xml(xml, key: :list_of_contentions)
        data = XMLHelper.convert_to_hash(xml.to_xml)[key]

        new(
          id: data[:@id],
          text: data[:@title],
          start_date: data[:start_date],
          submit_date: data[:submit_date]
        )
      end
    end
  end
end
