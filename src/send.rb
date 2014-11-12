#!/usr/bin/env ruby
require 'erb'
require 'xml'
require 'optparse'
require 'tempfile'

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

# prepare XML for document upload
# call UploadDocumentWithAssociations
# return decrypted message
def upload_doc(options)
  begin
    file = prepare_xml(options[:pdf], options[:claim_number])
    call_upload(file)
  ensure
    file.close
    file.unlink
  end
end

def prepare_xml(pdf, claim_number)
  #what ought to go in these variables?
  externalId = "123"
  fileNumber = "784449089"
  filename = "cui-test.pdf"
  docType = "546"
  subject = "cui-test"

  template = File.open("upload_document_xml_template.xml.erb", 'r').read
  xmlfile = Tempfile.new('xml')
  xmlfile.write(ERB.new(template).result(binding))
  xmlfile
end

def call_upload(xml)
  keyfile = "client3.jks"

  sh "java -classpath '.:../lib/*' UploadDocumentWithAssociations #{xml.path} #{keyfile}"
end

def parse(args)
  usage = "Usage: upload_doc.rb --pdf <filename> --claim_number <n> --env <env>"
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
      options[:env] = v
    end
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
