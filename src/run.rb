#!/usr/bin/env ruby
require 'byebug'
require 'pry'
require 'savon'
require 'xml'

url = "https://filenet.test.vbms.aide.oit.va.gov/vbmsp2-cms/streaming/eDocumentService-v4?WSDL"
client = Savon.client(wsdl: url, ssl_verify_mode: :none)#, ssl_cert_file: "vbms_test_public_key.crt")
doc = XML::Parser.string(STDIN.read).parse

# inject SAML header
saml = doc.import(XML::Parser.file("samlToken-cui-tst.xml").parse.root)
wsse = "wsse:http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
doc.find_first("//wsse:Security", wsse) << saml

# remove mustUnderstand attr
doc.find_first("//wsse:Security", wsse).attributes.get_attribute("mustUnderstand").remove!

doc.save("intermediate_files/encrypted_saml.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
xml = doc.to_s
puts xml

begin
  puts "============= message =============="
  response = client.call(:get_document_types, xml: xml)
  raw = response.to_xml
  File.open("intermediate_files/raw_response.xml", 'w').write(raw)
  respxml = XML::Parser.string(raw).parse
  respxml.save("intermediate_files/response.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
rescue Exception => e
  puts e
  puts "intermediate_files/encrypted_saml.xml contains the message that just failed"
end
