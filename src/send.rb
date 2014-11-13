#!/usr/bin/env ruby
require 'erb'
require 'xml'
require 'optparse'
require 'savon'
require 'tempfile'

ENVS = {
  "test" => {
    :url => "https://filenet.test.vbms.aide.oit.va.gov/vbmsp2-cms/streaming/eDocumentService-v4",
    :keyfile => "client3.jks",
    :saml => "samlToken-cui-tst.xml"
  }
}

# global log function
$logfile = "/usr/local/var/log/connect_vbms.log"
def log(msg)
  log = File.open($logfile, 'a')
  log.write(msg)
  log.write("\n")
end

def sh(cmd)
  cmd.gsub! "\n", " \\\n"
  log(cmd)
  out = `#{cmd}`
  if $? != 0
    puts out
    puts cmd
    raise "command failed"
  end
  out
end

# prepare XML for document upload
# call UploadDocumentWithAssociations
# send XML, get response
# decrypt response
# return decrypted message
def upload_doc(options)
  begin
    file = prepare_xml(options[:pdf], options[:claim_number])
    encrypted_xml = prepare_upload(file, options[:env])
    puts send_document(encrypted_xml, options[:env], options[:pdf])
  rescue Exception => e
    puts e.backtrace
    puts e.message
  ensure
    file.close
    file.unlink
  end
end

def write_tempfile(data, name="temp")
  file = Tempfile.new(name)
  file.write(data)
  file.close
  file
end

def get_tempname(name="temp")
  file = Tempfile.new(name)
  path = file.path
  file.close
  file.unlink
  path
end

def prepare_xml(pdf, claim_number)
  #what ought to go in these variables?
  externalId = "123"
  fileNumber = "784449089"
  filename = "cui-test.pdf"
  docType = "546"
  subject = "cui-test"

  template = File.open("upload_document_xml_template.xml.erb", 'r').read
  xml = ERB.new(template).result(binding)
  log("Unencrypted XML:\n#{xml}")

  write_tempfile(xml)
end

def prepare_upload(xmlfile, env)
  sh "java -classpath '.:../lib/*' UploadDocumentWithAssociations #{xmlfile.path} #{env[:keyfile]}"
end

def inject_saml(doc, env)
  puts "parsing #{env[:saml]}"
  saml = doc.import(XML::Parser.file(env[:saml]).parse.root)
  wsse = "wsse:http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  doc.find_first("//wsse:Security", wsse) << saml
end

def remove_mustUnderstand(doc)
  wsse = "wsse:http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  doc.find_first("//wsse:Security", wsse).attributes.get_attribute("mustUnderstand").remove!
end

def send_document(xml, env, pdf)
  # inject SAML header
  doc = XML::Parser.string(xml).parse
  inject_saml(doc, env)
  remove_mustUnderstand(doc)
  xml = doc.to_s
  pdf = IO.read(pdf)
  req = ERB.new(File.open("mtom_request.erb").read).result(binding)
  reqfile = write_tempfile(req)
  logfilename = get_tempname("curl_trace")
  headers = 'Content-Type: Multipart/Related; type="application/xop+xml"; start-info="application/soap+xml"; boundary="boundary_1234"'

  sh <<-CMD
curl -H '#{headers}'
  --data-binary @#{reqfile.path}
  -i -k --trace-ascii #{logfilename}
  -X POST #{env[:url]}
  CMD
end

def parse(args)
  usage = "Usage: upload_doc.rb --pdf <filename> --claim_number <n> --env <env> --logfile <file>"
  options = {}

  OptionParser.new do |opts|
    opts.banner = usage

    opts.on("--pdf [filename]", "PDF file to upload") do |v|
      options[:pdf] = v
    end

    opts.on("--claim_number [n]", "Claim number") do |v|
      options[:claim_number] = v
    end

    opts.on("--env [env]", "Environment to use: test, UAT, ...") do |v|
      options[:env] = ENVS[v]
    end

    opts.on("--logfile [logfile]", "Logfile to use") do |v|
      $logfile = v
    end

    # TODO: add -v option for verboseness
  end.parse!

  required_options = [:env, :claim_number, :pdf]
  if !required_options.map{|opt| options.has_key? opt}.all?
    puts usage
    exit
  end

  options
end

options = parse(ARGV)
upload_doc(options)
