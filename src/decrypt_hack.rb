#!/usr/bin/env ruby
require 'xml'

log = File.open("soapui.log").read
xml = XML::Parser.string(log.match(/<soap:Body.*?soap:Body>/i)[0]).parse
xml.save("intermediate_files/decrypted_response.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
puts xml.to_s
