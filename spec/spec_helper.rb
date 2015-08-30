# encoding: utf-8
require 'simplecov'
SimpleCov.start do
    refuse_coverage_drop
end

# TODO: remove this once we can put our source code in `lib/`
$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "src")

require 'vbms'
require 'nokogiri'
require 'rspec/matchers'
require 'equivalent-xml'
require 'webmock/rspec'

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

def setup_webmock(endpoint_url, response_file, request_name)
  return if ENV.key?('CONNECT')

  response_path = fixture_path("requests/#{response_file}.xml")
  keystore_path = fixture_path('test_keystore.jks')

  encrypted = VBMS.encrypted_soap_document(response_path, keystore_path, 'importkey', request_name)
  # encrypt it

  stub_request(:post, endpoint_url).to_return(body: encrypted)
end


  # headers, body = response.split(/\n\n/, 2)

  # parsed_headers = Hash[headers.split("\n").map{ |s| s.scan(/^(\S+): (.+)/).first }]

  # fail "Can't find Date header" unless parsed_headers.key?('Date')
  # time = Time.parse(parsed_headers['Date'])
  # Timecop.freeze(time)


def cleanup_webmock
end

RSpec.configure do |config|
# The settings below are suggested to provide a good initial experience
# with RSpec, but feel free to customize to your heart's content.

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # If CONNECT_VBMS_KEYFILE is not set, don't run the integration tests
  if ENV.key?('CONNECT') && !ENV.key?('CONNECT_VBMS_KEYFILE')
    puts '¡¡¡ CONNECT_VBMS_KEYFILE is not set, not running integration tests!!!'
    config.filter_run_excluding integration: true
  end
end
