# frozen_string_literal: true

module AddExtSecurityHeader
  def inject_header_content(header_xml)
    Nokogiri::XML::Builder.with(header_xml) do |xml|
      xml["vbmsext"].userId("dslogon.1011239249", "xmlns:vbmsext" => "http://vbms.vba.va.gov/external")
      if @send_userid
        xml["ext"].Security("xmlns:ext" => "http://vbms.vba.va.gov/external") do
          xml["ext"].cssUserName # do not insert css id in here, this will be injected by the client
          xml["ext"].cssStationId
          xml["ext"].SecurityLevel security_level
        end
      end
    end
  end
end
