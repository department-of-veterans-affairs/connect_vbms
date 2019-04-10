module VBMS
  module Requests
    NAMESPACES = {
      "xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/",
      "xmlns:upload" => "http://service.efolder.vbms.vba.va.gov/eFolderUploadService",
      "xmlns:read" => "http://service.efolder.vbms.vba.va.gov/eFolderReadService",
      "xmlns:v5" => "http://vbms.vba.va.gov/cdm/document/v5",
      "xmlns:cdm" => "http://vbms.vba.va.gov/cdm",
      "xmlns:xop" => "http://www.w3.org/2004/08/xop/include"
    }.freeze

    def self.soap(more_namespaces: {})
      Nokogiri::XML::Builder.new do |xml|
        xml["soapenv"].Envelope(VBMS::Requests::NAMESPACES.merge(more_namespaces)) do
          xml["soapenv"].Body { yield(xml) }
        end
      end.doc
    end
  end
end
