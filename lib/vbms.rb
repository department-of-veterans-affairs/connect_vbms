#!/usr/bin/env ruby
# frozen_string_literal: true

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
require "vbms/errors"
require "vbms/version"
require "vbms/requests"

require "vbms/responses/claim"
require "vbms/responses/contention"
require "vbms/responses/disposition"

require "vbms/requests/base_request"
require "vbms/requests/add_ext_security_header"

require "vbms/requests/establish_claim"
require "vbms/requests/create_contentions"
require "vbms/requests/list_contentions"
require "vbms/requests/associate_rated_issues"
require "vbms/requests/remove_contention"
require "vbms/requests/update_contention"
require "vbms/requests/get_dispositions"

# eFolder Service 1.0
require "vbms/requests/find_document_series_reference"
require "vbms/requests/find_paged_document_series_references"
require "vbms/requests/find_document_version_reference"
require "vbms/requests/find_document_version_reference_by_date_range"
require "vbms/requests/get_document_content"
require "vbms/requests/initialize_upload"
require "vbms/requests/upload_document"
require "vbms/requests/list_type_category"

require "vbms/helpers/xml_helper"
require "vbms/helpers/multipart_parser"

# our services
require "vbms/service/base"
require "vbms/service/paged_documents"

# require 'xmldsig'
require "xmldsig/signature_override"
