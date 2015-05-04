#!/usr/bin/env ruby
require 'erb'
require 'httpi'
require 'optparse'
require 'tempfile'
require 'time'
require 'xml'
require 'pg'
require 'uri'

$filedir = File.dirname(File.absolute_path(__FILE__))

CLASSPATH = [
    File.join($filedir, '../classes'),
    File.join($filedir, '../lib'),
    File.join($filedir, '../lib/*'),
    $filedir,
].join(':')

# global log function
$logfile = "../log/connect_vbms.log"
def log(msg)
  log = open_relative($logfile, 'a')
  log.write("#{Time.now.utc.iso8601}: #{msg}")
  log.write("\n")
  log.write msg
end

# log to the DrTurboTax external_activity_log
def db_log(conn, message, request_body, response_body, evaluation_id)
  conn.exec_params(<<-EOM, [message, request_body, response_body, evaluation_id])
INSERT INTO external_activity_logs(message, submitted_data, response_body, evaluation_id)
VALUES ($1, $2, $3, $4)
  EOM
end

def rel(name)
  File.join($filedir, name)
end

# return open file relative to this file's current directory
def open_relative(name, mode='r')
  File.open(rel(name), mode)
end

def sh(cmd)
  cmd.gsub! "\n", " \\\n"
  log(cmd)
  puts cmd
  out = `#{cmd}`
  if $? != 0
    puts out
    puts cmd
    log("*** command failed: #{out}")
    raise "command failed"
  end
  out
end

# Given an env name (like "test", "uat", "pre") go get the appropriate environment
# variables and make them relative to this file. Return an env hash.
def getenv(environment_name)
  env = {}
  environment_directory = File.join(ENV["CONNECT_VBMS_ENV_DIR"], environment_name)
  env[:url] = ENV.fetch("CONNECT_VBMS_URL", nil)
  env[:keyfile] = ENV.fetch("CONNECT_VBMS_KEYFILE", nil)
  env[:saml] = ENV.fetch("CONNECT_VBMS_SAML", nil)
  env[:key] = ENV.fetch("CONNECT_VBMS_KEY", nil)
  env[:keypass] = ENV.fetch("CONNECT_VBMS_KEYPASS", nil)
  env[:cacert] = ENV.fetch("CONNECT_VBMS_CACERT", nil)
  env[:cert] = ENV.fetch("CONNECT_VBMS_CERT", nil)
  env[:pg] = ENV.fetch("CONNECT_VBMS_POSTGRES", nil)
  [:keyfile, :saml, :key, :cacert, :cert].each do |k|
    env[k] = File.absolute_path(File.join(environment_directory, env[k])) if env[k]
  end

  if env[:pg]
    uri = URI.parse(env[:pg])
    env[:pg] = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
  end

  env
end

# prepare XML for document upload
# call EncryptSOAPDocument
# send XML, get response
# check response for error
# decrypt response
# return decrypted message
def upload_doc(options)
  begin
    env = getenv(options[:env])
    log("Connecting with env: #{env}")
    file = prepare_xml(options[:pdf], options[:file_number], options[:received_dt], options[:first_name], options[:middle_name], options[:last_name], options[:exam_name])
    encrypted_xml = prepare_upload(file, env)
    response = send_document(encrypted_xml, env, options)
    decrypted_response = handle_response(response, env, options)
    puts decrypted_response
    if env[:pg]
      db_log(env[:pg], "connect_vbms decrypted response", "", decrypted_response, options[:file_number])
    end
  rescue Exception => e
    puts e.backtrace
    log(e.backtrace)
    puts e.message
    log(e.message)
    open_relative("../log/#{options[:file_number]}-signed.xml.log", 'a').write(encrypted_xml)
  ensure
    if file
      file.close
      file.unlink
    end
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

def prepare_xml(pdf, file_number, received_dt, first_name, middle_name, last_name, subject)
  #what ought to go in these variables?
  externalId = "123"
  filename = File.basename(pdf)

  # Mary Kate Alber told us via email that the doctype should be "C&P Exam",
  # and a getDocumentTypes call shows this as the proper docType
  docType = "356"

  # There is no docs on the time format. Guessing based on examples from the
  # soapui project that it's GMT, 24 hour clock YYYY-MM-DD-HH:MM. Discovered
  # through trial and error that it doesn't allow a 24 hour clock, so the time
  # of day field is utterly useless. Insane. Is it actually supposed to be
  # GMT: who knows?
  time = Time.iso8601(received_dt)
  receivedDt = time.getlocal("-05:00").strftime "%Y-%m-%d-05:00"

  source = "VHA_CUI"

  # TODO: true if the claim associated with this evaluation is still pending,
  # false otherwise
  newMail = "true"
  template = open_relative("templates/upload_document_xml_template.xml.erb").read
  xml = ERB.new(template).result(binding)
  log("Unencrypted XML:\n#{xml}")
  write_tempfile(xml)
end

def prepare_upload(xmlfile, env)
  sh "java -classpath '#{CLASSPATH}' EncryptSOAPDocument #{xmlfile.path} #{env[:keyfile]} #{env[:keypass]}"
end

def inject_saml(doc, env)
  log("parsing #{env[:saml]}")
  saml = doc.import(XML::Parser.file(env[:saml]).parse.root)
  wsse = "wsse:http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  doc.find_first("//wsse:Security", wsse) << saml
end

def remove_mustUnderstand(doc)
  wsse = "wsse:http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  doc.find_first("//wsse:Security", wsse).attributes.get_attribute("mustUnderstand").remove!
end

def build_request(url, data, headers, key: nil, keypass: nil, cert: nil, cacert: nil)
  request = HTTPI::Request.new(url)

  if key
    log("Auth\nkey: #{key}\ncert: #{cert}\nca_cert: #{cacert}")
    request.auth.ssl.cert_key_file     = key
    request.auth.ssl.cert_key_password = keypass
    request.auth.ssl.cert_file         = cert
    request.auth.ssl.ca_cert_file      = cacert
    request.auth.ssl.verify_mode       = :peer
  else
    log("No Auth")
    request.auth.ssl.verify_mode = :none
  end

  request.body = data

  request.headers = headers
  request
end

def send_document(xml, env, options)
  # inject SAML header
  doc = XML::Parser.string(xml).parse
  inject_saml(doc, env)
  remove_mustUnderstand(doc)
  xml = doc.to_s
  open_relative("../log/#{options[:file_number]}-final.xml.log", 'a').write(xml)
  filename = File.split(options[:pdf])[1]
  pdf = IO.read(options[:pdf])
  req = ERB.new(open_relative("templates/mtom_request.erb").read).result(binding)
  headers = {
    'Content-Type' => 'Multipart/Related; type="application/xop+xml"; start-info="application/soap+xml"; boundary="boundary_1234"'
  }

  # for the rest, grab the cert and ca
  if env[:cacert]
    key = env[:key]
    keypass = env[:keypass]
    cert = env[:cert]
    cacert = env[:cacert]
  else
    key = keypass = cert = cacert = nil
  end

  request = build_request(env[:url], req, headers, key: key, keypass: keypass, cert: cert, cacert: cacert)
  begin
    response = HTTPI.post(request)
  rescue => e
    puts e.class
  end
  log("response code: #{response.code}")
  log("response headers: #{response.headers}")
  log("response body: #{response.body}")

  # Let's submit the file_number instead of the evaluation_id, since we don't have that info here?
  if env[:pg]
    db_log(env[:pg], "connect_vbms status #{response.code}", xml, response.body, options[:file_number])
  end

  response.body
end

def handle_response(response, env, options)
  soap_txt = response.match(/<soap:envelope.*?<\/soap:envelope>/im)[0]
  doc = XML::Parser.string(soap_txt).parse

  # Do NOT use doc.to_s. This pretty-prints the XML improperly by
  # tabifying it. Since Whitespace in XML is semantically meaningful,
  # this will chanage the SHA1 Digest causing signature validation to
  # fail.
  log("Response from VBMS:\n#{soap_txt}")

  soap = "http://schemas.xmlsoap.org/soap/envelope/"
  if doc.find_first("//soap:Fault", soap)
    $stderr.write("Received error from VBMS:\n#{soap_txt}\nCheck logfile in #{$logfile}\n")
    exit
  end

  file = write_tempfile(soap_txt)

  # now here's the hackiest thing in the world. This command is going to fail,
  # because we can't get the signatures to properly get decrypted. So run the
  # command, handle the error, and pull the message out of the file >:|
  fname = rel("../log/#{options[:file_number]}.decrypt.log")
  sh "java -classpath '#{CLASSPATH}' DecryptMessage #{file.path} #{env[:keyfile]} '#{fname}'"
end

def parse(args)
  usage = "Usage: send.rb --pdf <filename> --env <env> --file_number <n> --received_dt <dt> --first_name <name> --middle_name [<name>] --last_name <name> --logfile [<file>] "
  options = {}

  parser = OptionParser.new do |opts|
    opts.banner = usage

    opts.on("--pdf <filename>", "PDF file to upload") do |v|
      options[:pdf] = v
    end

    opts.on("--file_number <n>", "File number") do |v|
      options[:file_number] = v
    end

    opts.on("--received_dt <dt>", "Time in iso8601 GMT") do |t|
      options[:received_dt] = t
    end

    opts.on("--first_name <name>", "Veteran first name") do |n|
      options[:first_name] = n
    end

    opts.on("--middle_name [<name>]", "Veteran middle name") do |n|
      options[:middle_name] = n
    end

    opts.on("--last_name <name>", "Veteran last name") do |n|
      options[:last_name] = n
    end

    opts.on("--exam_name <name>", "Name of the exam being sent") do |n|
      options[:exam_name] = n
    end

    opts.on("--env [env]", "Environment to use: test, UAT, ...") do |v|
      options[:env] = v
    end

    opts.on("--logfile [logfile]", "Logfile to use. Defaults to ../log/connect_vbms.log") do |v|
      $logfile = v
    end
  end

  parser.parse!

  required_options = [:env, :file_number, :pdf, :received_dt, :first_name, :last_name, :exam_name]
  if !required_options.map{|opt| options.has_key? opt}.all?
    puts "missing keys #{required_options.select{|opt| !options.has_key? opt}}"
    puts parser.help
    exit
  end

  options
end

options = parse(ARGV)
upload_doc(options)
