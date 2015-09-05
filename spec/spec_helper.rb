# encoding: utf-8
require 'simplecov'
SimpleCov.start do
  refuse_coverage_drop
end

# TODO: remove this once we can put our source code in `lib/`
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'src')

require 'vbms'
require 'nokogiri'
require 'rspec/matchers'
require 'equivalent-xml'

require 'byebug' if RUBY_PLATFORM != 'java'

if ENV.key?('CONNECT_VBMS_RUN_EXTERNAL_TESTS')
  puts "WARNING: CONNECT_VBMS_RUN_EXTERNAL_TESTS set, the tests will connect to live VBMS test servers\n"
else
  require 'webmock/rspec'
end

def env_path(env_dir, env_var_name)
  value = ENV[env_var_name]
  if value.nil?
    return nil
  else
    return File.join(env_dir, value)
  end
end

def fixture_path(filename)
  File.join(File.expand_path('../fixtures', __FILE__), filename)
end

def fixture(path)
  File.read fixture_path(path)
end

FILEDIR = File.dirname(File.absolute_path(__FILE__))
DO_WSSE = File.join(FILEDIR, '../src/do_wsse.sh')

# Note: these should not be replaced with calls to the similar functions in VBMS, since
# I want them to continue to call the Java WSSE utility even when encryption/decryption in
# gem is done in Ruby, so we can check as against Ruby methods
def encrypted_xml_file(response_path, request_name)
  keystore_path = fixture_path('test_keystore.jks')

  args = [DO_WSSE,
          '-e',
          '-i', response_path,
          '-k', keystore_path,
          '-p', 'importkey',
          '-n', request_name]
  output, errors, status = Open3.capture3(*args)

  if status != 0
    fail VBMS::ExecutionError.new(DO_WSSE + ' EncryptSOAPDocument', errors)
  end

  output
end

def encrypted_xml_buffer(xml, request_name)
  Tempfile.open('tmp') do |t|
    t.write(xml)
    t.flush
    return encrypted_xml_file(t.path, request_name)
  end
end

def webmock_soap_response(endpoint_url, response_file, request_name)
  return if ENV.key?('CONNECT_VBMS_RUN_EXTERNAL_TESTS')

  response_path = fixture_path("requests/#{response_file}.xml")

  encrypted = encrypted_xml_file(response_path, request_name)
  stub_request(:post, endpoint_url).to_return(body: encrypted)
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
