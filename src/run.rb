#!/usr/bin/env ruby
require 'byebug'
require 'pry'
require 'savon'
require 'xml'

def sh(cmd)
  # http://sgros.blogspot.com/2013/01/signing-xml-document-using-xmlsec1.html
  # explains how this works
  cmd.gsub! "\n", " \\\n"
  puts cmd
  out = `#{cmd}`
  if $? != 0
    puts out
    puts cmd
    raise "command failed"
  end
  out
end

url = "https://filenet.test.vbms.aide.oit.va.gov/vbmsp2-cms/streaming/eDocumentService-v4"
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
pdf = IO.read("cui-test.pdf")

request = <<-REQ
--boundary_1234\r
Content-Type: application/xop+xml; type="application/soap+xml"; charset=utf-8\r
\r
#{xml}
\r
\r
--boundary_1234\r
Content-Type: application/octet-stream\r
Content-ID: cui-test.pdf\r
\r
#{pdf}
\r
--boundary_1234\r
REQ

File.open("intermediate_files/request_curl.txt", 'w').write(request)

begin
  puts "============= beginning request =============="
  cmd = <<-CMD
curl -H 'Content-Type: Multipart/Related; type="application/xop+xml"; start-info="application/soap+xml"; boundary="boundary_1234"'
  --data-binary @intermediate_files/request_curl.txt
  -i -k --trace-ascii intermediate_files/curl_trace.txt
  -X POST https://filenet.test.vbms.aide.oit.va.gov/vbmsp2-cms/streaming/eDocumentService-v4
  CMD
  response = sh(cmd)
  puts "============= request over =============="
  File.open("intermediate_files/raw_response.txt", 'w').write(response)
  puts response
rescue Exception => e
  puts e
  puts "intermediate_files/encrypted_saml.xml contains the message that just failed"
  raise
end

# Now grab the meat of the returned message
xml = XML::Parser.string(response.match(/<soap:envelope.*?<\/soap:envelope>/im)[0]).parse
xml.save("intermediate_files/raw_response.xml", :indent => true, :encoding => XML::Encoding::UTF_8)