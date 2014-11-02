require 'byebug'
require 'pry'
require 'savon'

url = "https://filenet.test.vbms.aide.oit.va.gov/vbmsp2-cms/streaming/eDocumentService-v4?WSDL"
client = Savon.client(wsdl: url, ssl_verify_mode: :none)#, ssl_cert_file: "vbms_test_public_key.crt")
xml = STDIN.read
puts xml
begin
  puts client.call(:get_document_types, xml: xml)
rescue Exception => e
  puts e
  puts "intermediate_files/encrypted_saml.xml contains the message that just failed"
end
