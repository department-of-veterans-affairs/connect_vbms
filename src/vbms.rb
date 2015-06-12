#!/usr/bin/env ruby
require 'base64'
require 'erb'
require 'httpi'
require 'tempfile'
require 'uri'
require 'nokogiri'

require 'vbms/common'
require 'vbms/client'
require 'vbms/requests'
require 'vbms/db_logger'

if ENV.has_key? "CONNECT_VBMS_POSTGRES"
  begin
    require 'pg'
  rescue LoadError
    print <<-EOF
Unable to load the 'pg' gem, which is required if the CONNECT_VBMS_POSTGRES
environment variable is set. Please either install the 'pg' gem or unset
the CONNECT_VBMS_POSTGRES environment variable.
    EOF
    raise
  end
end
