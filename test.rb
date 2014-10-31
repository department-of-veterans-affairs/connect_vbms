require 'savon'
require 'byebug'
require 'pry'
require 'tempfile'
require 'time'

url = "https://filenet.test.vbms.aide.oit.va.gov/vbmsp2-cms/streaming/eDocumentService-v4?WSDL"
client = Savon.client(wsdl: url)

# need to add the VBMS cert to the store, I think for this to work?
# http://lowly-tech.blogspot.com/2013/04/savon-for-webservices-easy-enough-to.html
# client.operations
#
# for now just turn that shit off 
# http://savonrb.com/version2/globals.html
client = Savon.client(wsdl: url, ssl_verify_mode: :none)#, ssl_cert_file: "vbms_test_public_key.crt")

# This returns a 503 (The server is currently unavailable)
# client.call(:get_document_types)

# let's just build our own request
require 'xml'

def node(name, value:"", attrs:{}, parent:nil)
  n = XML::Node.new(name, value.to_s)

  attrs.each do |attr, val|
    n.attributes[attr.to_s] = val
  end

  # append the node to its parent if it has one
  if parent
    parent << n
  end

  n
end

doc = XML::Document.new
root = node("soap:Envelope", attrs: {
  "xmlns:vbms" => "http://vbms.vba.va.gov/external/eDocumentService/v4",
  "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/",
  "xmlns:wsse" => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd",
  "xmlns:wsu"  => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd",
  "xmlns:ds"   => "http://www.w3.org/2000/09/xmldsig#",
  "xmlns:xenc" => "http://www.w3.org/2001/04/xmlenc#"
})
doc.root = root

def addtimestamp(security)
  st = node("wsu:Timestamp", attrs: {"wsu:Id" => "timestamp"}, parent: security)
    t = Time.now
    # five minutes from now
    f = Time.now + 300
    cr = node("wsu:Created", parent: st, value: t.utc.iso8601)
    ex = node("wsu:Created", parent: st, value: f.utc.iso8601)
end

def addref(signedinfo, refId)
  ref = node("ds:Reference", attrs: {"URI" => refId}, parent: signedinfo)
    trs = node("ds:Transforms", parent: ref)
      tr  = node("ds:Transform",
                 attrs: {"Algorithm" => "http://www.w3.org/2000/09/xmldsig#enveloped-signature"},
                 parent: trs)
    dig = node("ds:DigestMethod", attrs: {"Algorithm" => "http://www.w3.org/2000/09/xmldsig#sha1"}, parent: ref)
    div = node("ds:DigestValue", parent: ref)
end

def addheader(root)
  header = node("soap:Header", parent: root)
  #sec = node("wsse:Security", attrs: {"soap:mustUnderstand" => "1"}, parent: header)
  sec = node("wsse:Security", parent: header)
  sig = node("ds:Signature", parent: sec)
    si = node("ds:SignedInfo", parent: sig)
      can = node("ds:CanonicalizationMethod", attrs: {"Algorithm" => "http://www.w3.org/2001/10/xml-exc-c14n#"}, parent: si)
      met = node("ds:SignatureMethod", attrs: {"Algorithm" => "http://www.w3.org/2000/09/xmldsig#rsa-sha1"}, parent: si)
      addref(si, "#id-7")
      addref(si, "#timestamp")
    val = node("ds:SignatureValue", parent: sig)
    ki = node("ds:KeyInfo", parent: sig)
      str = node("wsse:SecurityTokenReference", parent: ki)
        dat = node("ds:X509Data", parent: str)
          is = node("ds:X509IssuerSerial", parent: dat)
            # TODO: generate both of these rather than sticking them in there
            ina = node("ds:X509IssuerName", value: "C=US, ST=SC, L=Charleston, O=VA, OU=VBMS, CN=cui to VBMS", parent: is)
            sn = node("ds:X509SerialNumber", value: "10750083120540719457", parent: is)

  addtimestamp(sec)
  root
end

def getDocType(root)
  # the ds:SignedInfo node points here
  body = node("soap:Body", attrs: {"wsu:Id" => "id-7"}, parent: root)
    meth = node("vbms:getDocumentTypes", parent: body)
end

def sign(xml)
  unenc = File.new("xml.xml", 'w')
  unenc.write(xml)
  unenc.close
  # http://sgros.blogspot.com/2013/01/signing-xml-document-using-xmlsec1.html
  # explains how this works
  cmd = "xmlsec1 --sign --privkey-pem cui-tst-client.key --pwd importkey --output signed.xml --id-attr:Id Body --id-attr:Id Timestamp #{unenc.path}"
  puts cmd
  out = `#{cmd}`
  if $? != 0
    puts xml
    puts out
    raise "Failed to sign XML"
  end
  File.read("signed.xml")
end

def encrypt_body(xml)
  File.open("signed_saml.xml", 'w').write(xml.to_s)
  #cmd ="xmlsec1 encrypt --pubkey-cert-pem vbms.cms.test.vbms.aide.oit.va.gov.crt --pwd importkey --session-key des-192 \
#--xml-data signed_saml.xml --output signed_body.xml --node-xpath \
#/soap:Envelope/soap:Body/vbms:getDocumentTypes \
#session-key-template.xml"
  # let's try removing the session key
  # I can't seem to get this to work. Unclear why. Revisit.
#  cmd ="xmlsec1 encrypt --pubkey-cert-pem vbms.cms.test.vbms.aide.oit.va.gov.crt --pwd importkey \
#--xml-data signed_saml.xml --output signed_body.xml --node-xpath \
#/soap:Envelope/soap:Body/vbms:getDocumentTypes \
#session-key-template.xml"
  #How about removing the getDocumenttypes bit
  cmd = <<-XML
xmlsec1 encrypt --pubkey-cert-pem vbms.cms.test.vbms.aide.oit.va.gov.crt \
--pwd importkey --session-key des-192 --xml-data signed_saml.xml  \
--output signed_body.xml --node-xpath /soap:Envelope/soap:Body \
session-key-template.xml
  XML
  puts cmd
  out = `#{cmd}`
  if $? != 0
    puts xml
    puts out
    raise "Failed to sign XML"
  end
  File.read("signed_body.xml")
end

# import an xml string into a document
def import(doc, parent, xmls)
  node = doc.import(XML::Parser.string(xmls).parse.root)
  parent << node
end

def fixEncKey(xml)
  # Grab the EncryptedKey element and move it into the Security element
  doc = XML::Parser.string(xml).parse
  n = doc.find("//xenc:EncryptedKey", 'xenc:http://www.w3.org/2001/04/xmlenc#')[0]
  keyinfo = n.parent
  n["Id"] = "bodyek"
  n.remove!
  doc.find("//wsse:Security")[0] << n

  # Create a reference to ED-22 (the body's EncryptedData element)
  ref = import(doc, n, '<xenc:ReferenceList><xenc:DataReference URI="#ED-22"/></xenc:ReferenceList>')

  # Create a reference to the EncryptedKey element in the soap body
  ref = import(doc, keyinfo, <<-XML)
        <wsse:SecurityTokenReference xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:wsse11="http://docs.oasis-open.org/wss/oasis-wss-wssecurity-secext-1.1.xsd" wsse11:TokenType="http://docs.oasis-open.org/wss/oasis-wss-soap-message-security-1.1#EncryptedKey">
          <wsse:Reference URI="#bodyek"/>
        </wsse:SecurityTokenReference>
  XML

  doc.save("fixed_encKey.xml", :indent => true, :encoding => XML::Encoding::UTF_8)
  doc
end

addheader(root)
getDocType(root)

signed_xml = sign(doc.to_s)
signed_doc = XML::Parser.string(signed_xml).parse

# add the saml token to the xml
saml = signed_doc.import(XML::Parser.file("samlToken-cui-tst.xml").parse.root)
signed_doc.find("//wsse:Security").to_a[0] << saml

# now encrypt the body
encrypted_body = encrypt_body(signed_doc)

fixed_doc = fixEncKey(encrypted_body)
puts fixed_doc.to_s

begin
  puts client.call(:get_document_types, xml: fixed_doc.to_s)
rescue Exception => e
  pry.binding
end
