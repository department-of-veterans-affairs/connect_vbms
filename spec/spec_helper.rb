# encoding: utf-8
# frozen_string_literal: true
require "simplecov"
SimpleCov.start do
end

# TODO: remove this once we can put our source code in `lib/`
$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "src")

require "vbms"
require "nokogiri"
require "rspec/matchers"
require "equivalent-xml"
require "pry"
require "httplog" if ENV["CONNECT_VBMS_HTTPLOG"] && ENV["CONNECT_VBMS_HTTPLOG"] == 1
require "byebug" if RUBY_PLATFORM != "java"
require "httpi"

if ENV.key?("CONNECT_VBMS_RUN_EXTERNAL_TESTS")
  puts "WARNING: CONNECT_VBMS_RUN_EXTERNAL_TESTS set, the tests will connect to live VBMS test servers\n"
else
  require "webmock/rspec"
end

def decrypted_symmetric_key(cipher, p12_file)
  server_p12 = OpenSSL::PKCS12.new(File.read(p12_file), @keypass)
  server_p12.key.private_decrypt(cipher)
end

def env_path(env_dir, env_var_name)
  value = ENV[env_var_name]
  return nil if value.nil?

  File.join(env_dir, value)
end

def fixture_path(filename)
  File.join(File.expand_path("../fixtures", __FILE__), filename)
end

def fixture(path)
  File.read fixture_path(path)
end

def parse_strict(xml_string)
  Nokogiri::XML(xml_string, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
end

FILEDIR = File.dirname(File.absolute_path(__FILE__))
DO_WSSE = File.join(FILEDIR, "../src/do_wsse.sh")

# Note: these should not be replaced with calls to the similar functions in VBMS, since
# I want them to continue to call the Java WSSE utility even when encryption/decryption in
# gem is done in Ruby, so we can check as against Ruby methods
def encrypted_xml_file(response_path, keyfile, request_name)
  args = [DO_WSSE,
          "-e",
          "-i", response_path,
          "-k", keyfile,
          "-p", "importkey",
          "-n", request_name]
  output, errors, status = Open3.capture3(*args)

  if status != 0
    fail VBMS::ExecutionError.new(DO_WSSE + " EncryptSOAPDocument", errors)
  end

  output
end

def encrypted_xml_buffer(xml, keyfile, request_name)
  Tempfile.open("tmp") do |t|
    t.write(xml)
    t.flush
    return encrypted_xml_file(t.path, keyfile, request_name)
  end
end

def get_encrypted_file(filename, request_name)
  encrypted_xml_file(fixture_path("requests/#{filename}.xml"), fixture_path("test_server.jks"), request_name)
end

def java_decrypt_file(infile,
                      keyfile,
                      keypass,
                      ignore_timestamp = false)
  args = [DO_WSSE,
          "-i", infile,
          "-k", keyfile,
          "-p", keypass,
          "-l", "decrypt.log",
          ignore_timestamp ? "-t" : ""]
  begin
    output, errors, status = Open3.capture3(*args)
  rescue TypeError
    # sometimes one of the Open3 return values is a nil and it complains about coercion
    fail VBMS::ExecutionError.new(DO_WSSE + args.join(" ") + ": DecryptMessage", errors) if status != 0
  end

  fail VBMS::ExecutionError.new(DO_WSSE + " DecryptMessage", errors) if status != 0

  output
end

def java_decrypt_xml(xml,
                     keyfile,
                     keypass,
                     ignore_timestamp = false)

  Tempfile.open("tmp") do |t|
    t.write(xml)
    t.flush
    return java_decrypt_file(t.path, keyfile, keypass,
                             ignore_timestamp: ignore_timestamp)
  end
end

def webmock_soap_response(endpoint_url, response_file, request_name)
  return if ENV.key?("CONNECT_VBMS_RUN_EXTERNAL_TESTS")
  encrypted = get_encrypted_file(response_file, request_name)
  stub_request(:post, endpoint_url).to_return(body: encrypted)
end

def split_message(message)
  header_section, body_text = message.split(/\r\n\r\n/, 2)
  headers = Hash[header_section.split(/\r\n/).map { |s| s.scan(/^(\S+): (.+)/).first }]

  [headers, body_text]
end

def webmock_multipart_response(endpoint_url, response_file, request_name)
  return if ENV.key?("CONNECT_VBMS_RUN_EXTERNAL_TESTS")

  encrypted_xml = get_encrypted_file(response_file, request_name)
  response = File.read("spec/fixtures/requests/#{response_file}.txt")

  headers, body_text = split_message(response)
  body = ERB.new(body_text).result(binding)

  stub_request(:post, endpoint_url).to_return(body: body, headers: headers)
end

def parsed_timestamp(xml)
  x = xml.at_xpath("//wsu:Timestamp", VBMS::XML_NAMESPACES)

  {
    id: x["wsu:Id"],
    created: x.at_xpath("//wsu:Created", VBMS::XML_NAMESPACES).text,
    expires: x.at_xpath("//wsu:Expires", VBMS::XML_NAMESPACES).text
  }
end

# to generate test files, run rake fixtures
def new_test_client
  VBMS::Client.new(
    base_url: "http://test.endpoint.url/",
    keypass: "importkey",
    client_keyfile: fixture_path("test_client.p12"),
    server_cert: fixture_path("test_server.crt"),
    saml: fixture_path("test_samltoken.xml")
  )
end

RSpec.configure do |config|
  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.
  #
  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.color = true
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = :documentation
  end
end
