require 'spec_helper'

describe "Ruby Encrypt/Decrypt test vs Java reference impl" do
  it "takes a cleartext soap message, encrypts in ruby, and decrypts using java" do
    encrypted_message = Nokogiri::XML(fixture('encrypted_response.xml'))
    data = VBMS.shell_java("DecryptMessage #{fixture_path('encrypted_response.xml')} /Users/awong/src/VA/connect_vbms/creds/test/client3.jks importkey /tmp/decrypt_result.xml")
    #puts data
  end

  it "takes a cleartext soap message, encrypts in java, and decrypts using ruby" do
  end
end
