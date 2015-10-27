module VBMS
  module Requests
    def self.soap
      Nokogiri::XML::Builder.new do |xml|
        xml['soapenv'].Envelope(VBMS::ENVELOPE_NAMESPACE_DECLARATIONS) do
          xml['soapenv'].Header
          xml['soapenv'].Body { yield(xml) }
        end
      end.to_xml
    end
  end
end
