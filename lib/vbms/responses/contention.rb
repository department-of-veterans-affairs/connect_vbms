module VBMS
  module Responses
    class Contention
      attr_accessor :id, :text, :submit_date, :start_date
  
      def initialize(id:, text:, submit_date:, start_date:)
        self.id = id
        self.text = text
        self.submit_date = submit_date
        self.start_date = start_date
      end
  
      def self.create_from_xml(xml)
        start_date = xml.at_xpath("ns0:startDate/text()", VBMS::XML_NAMESPACES)
        submit_date = xml.at_xpath("ns0:submitDate/text()", VBMS::XML_NAMESPACES)

        new(
          id: xml["id"],
          text: xml["title"],
          start_date: start_date && Time.parse(start_date.content).to_date,
          submit_date: submit_date && Time.parse(submit_date.content).to_date
        )
      end
    end
  end
end
