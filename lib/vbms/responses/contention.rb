module VBMS
  module Responses
    class Contention < OpenStruct
      def self.create_from_xml(xml)
        data = XMLHelper.convert_to_hash(xml.to_xml)[:list_of_contentions]

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
