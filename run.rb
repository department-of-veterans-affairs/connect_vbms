require 'byebug'
require 'pry'
require 'savon'
require 'time'
require 'xml'

def sh(cmd)
  puts cmd
  out = `#{cmd}`
  if $? != 0
    puts xml
    puts out
    raise "command failure, exited"
  end
end

doc = XML::Parser.string(File.read('template.xml')).parse

# insert the time
ns = "wsu:http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
t = Time.now
# five minutes from now
f = Time.now + 300
doc.find_first("//wsu:Created", ns).content = t.utc.iso8601
doc.find_first("//wsu:Expires", ns).content = f.utc.iso8601

# clear out the DigestValues
ds = "ds:http://www.w3.org/2000/09/xmldsig#"
doc.find("//ds:DigestValue", ds).each { |dv| dv.content="" }
doc.find("//ds:SignatureValue", ds).each { |sv| sv.content="" }

# remove the saml header
ss = "saml2:urn:oasis:names:tc:SAML:2.0:assertion"
doc.find_first("//saml2:Assertion", ss).remove!

doc.save("intermediate_files/signature_template.xml", :indent => true, :encoding => XML::Encoding::UTF_8)

# sign the doc
sh "xmlsec1 --sign --privkey-pem cui-tst-client.key --pwd importkey --output intermediate_files/signed.xml --id-attr:Id Body --id-attr:Id Timestamp intermediate_files/signature_template.xml"
doc = XML::Parser.file("intermediate_files/signed.xml").parse

# clear out the CipherValues
xenc = "xenc:http://www.w3.org/2001/04/xmlenc#"
doc.find("//xenc:CipherValue", xenc).each { |cv| cv.content="" }
doc.save("intermediate_files/signed_emptied.xml", :indent => true, :encoding => XML::Encoding::UTF_8)

# encrypt the file
sh "xmlsec1 encrypt --pubkey-cert-pem vbms.cms.test.vbms.aide.oit.va.gov.crt --pwd importkey --session-key des-192 --xml-data intermediate_files/signed_emptied.xml --output intermediate_files/encrypted.xml --node-xpath /soapenv:Envelope/soapenv:Body/* session-key-template.xml"
doc = XML::Parser.file("intermediate_files/encrypted.xml").parse

# inject the saml token
saml = doc.import(XML::Parser.file("samlToken-cui-tst.xml").parse.root)
wsse = "wsse:http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
doc.find_first("//wsse:Security", wsse) << saml

doc.save("intermediate_files/encrypted_saml.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
doc = XML::Parser.file("intermediate_files/encrypted_saml.xml").parse

url = "https://filenet.test.vbms.aide.oit.va.gov/vbmsp2-cms/streaming/eDocumentService-v4?WSDL"
client = Savon.client(wsdl: url, ssl_verify_mode: :none)#, ssl_cert_file: "vbms_test_public_key.crt")
begin
  puts client.call(:get_document_types, xml: doc.to_s)
rescue Exception => e
  puts e
  puts "intermediate_files/encrypted_saml.xml contains the message that just failed"
end
