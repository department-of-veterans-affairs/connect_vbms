#!/usr/bin/env ruby
require "base64"
require "benchmark"
require "erb"
require "httpclient"
require "httpi"
require "tempfile"
require "uri"
require "nokogiri"
require "mail"

require "soap_scum/crypto_algorithms"
require "soap_scum/xml_namespaces"
require "soap_scum/ws_security"

require "vbms/common"
require "vbms/client"
require "vbms/version"
require "vbms/requests"

require "vbms/responses/document"
require "vbms/responses/document_type"
require "vbms/responses/document_with_content"
require "vbms/responses/claim"

require "vbms/requests/base_request"
# eDocument Service v4
require "vbms/requests/upload_document_with_associations"
require "vbms/requests/list_documents"
require "vbms/requests/fetch_document_by_id"
require "vbms/requests/get_document_types"
require "vbms/requests/establish_claim"

# eFolder Service 1.0
require "vbms/requests/find_document_series_reference"
require "vbms/requests/get_document_content"

require "vbms/helpers/xml_helper"

# require 'xmldsig'
require "xmldsig/signature_override"
