#!/usr/bin/env ruby
require 'base64'
require 'erb'
require 'httpi'
require 'tempfile'
require 'uri'
require 'nokogiri'

require 'vbms/common'
require 'vbms/client'
require 'vbms/version'
require 'vbms/requests'

require 'vbms/requests/upload_document_with_associations'
require 'vbms/requests/list_documents'
require 'vbms/requests/fetch_document_by_id'
require 'vbms/requests/get_document_types'
