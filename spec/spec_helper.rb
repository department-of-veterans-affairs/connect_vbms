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
require 'vbms_spec_helper'
require 'pry'
require 'httplog' if ENV['CONNECT_VBMS_HTTPLOG'] and ENV['CONNECT_VBMS_HTTPLOG'] == 1
require 'byebug' if RUBY_PLATFORM != 'java'
require 'httpi'

if ENV.key?('CONNECT_VBMS_RUN_EXTERNAL_TESTS')
  puts "WARNING: CONNECT_VBMS_RUN_EXTERNAL_TESTS set, the tests will connect to live VBMS test servers\n"
else
  require 'webmock/rspec'
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

