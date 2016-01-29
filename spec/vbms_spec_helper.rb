# Contains our helper methods to DRY out our specs
# 
# 
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

def parse_strict(xml_string)
  Nokogiri::XML(xml_string, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
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

def get_encrypted_file(filename, request_name)
  encrypted_xml_file(fixture_path("requests/#{filename}.xml"), request_name)
end

def webmock_soap_response(endpoint_url, response_file, request_name)
  return if ENV.key?('CONNECT_VBMS_RUN_EXTERNAL_TESTS')
  encrypted = get_encrypted_file(response_file, request_name)
  stub_request(:post, endpoint_url).to_return(body: encrypted)
end

def split_message(message)
  header_section, body_text = message.split(/\r\n\r\n/, 2)
  headers = Hash[header_section.split(/\r\n/).map { |s| s.scan(/^(\S+): (.+)/).first }]

  [headers, body_text]
end

def webmock_multipart_response(endpoint_url, response_file, request_name)
  return if ENV.key?('CONNECT_VBMS_RUN_EXTERNAL_TESTS')

  encrypted_xml = get_encrypted_file(response_file, request_name)
  response = File.read("spec/fixtures/requests/#{response_file}.txt")

  headers, body_text = split_message(response)
  body = ERB.new(body_text).result(binding)

  stub_request(:post, endpoint_url).to_return(body: body, headers: headers)
end

def parsed_timestamp(xml)
  x = xml.at_xpath('//wsu:Timestamp', VBMS::XML_NAMESPACES)

  {
    id: x['wsu:Id'],
    created: x.at_xpath('//wsu:Created', VBMS::XML_NAMESPACES).text,
    expires: x.at_xpath('//wsu:Expires', VBMS::XML_NAMESPACES).text
  }
end

def decrypted_symmetric_key(cipher)
  server_p12 = OpenSSL::PKCS12.new(File.read(@server_p12_key), @keypass)
  server_p12.key.private_decrypt(cipher)
end

def new_test_client
  VBMS::Client.new(
    'http://test.endpoint.url/', 
    fixture_path('test_keystore_importkey.p12'),
    fixture_path('test_samltoken.xml'),
    nil,
    'importkey',
    nil,
    nil,
    fixture_path('test_keystore_vbms_server_key.p12'),
    nil,
    fixture_path('test_keystore.jks')
  )
end
