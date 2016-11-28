def create_self_signed_cert(directory:, name:)
  `openssl req -x509 \
    -newkey rsa:4096 \
    -keyout #{directory}#{name}.key \
    -out #{directory}#{name}.crt \
    -nodes \
    -subj "/C=US/ST=DC/L=Washington/O=Dis/CN=connect-vbms.ds.va.gov" \
    -days 1001`
end

def create_jks(directory:, name:, public_name:)
  `keytool -importkeystore -noprompt \
    -destkeystore "#{directory}#{name}.jks" \
    -srckeystore "#{directory}#{name}.p12" \
    -srcstorepass importkey \
    -srcstoretype pkcs12 \
    -alias importkey \
    -destalias importkey \
    -deststorepass importkey`

  `keytool -importcert -noprompt \
    -alias public \
    -trustcacerts \
    -file #{directory}#{public_name}.crt \
    -keystore #{directory}#{name}.jks \
    -storepass importkey`
end

def create_pkcs12(directory:, name:)
  `openssl pkcs12 -export \
    -name importkey \
    -password pass:importkey \
    -out #{directory}#{name}.p12 \
    -inkey #{directory}#{name}.key \
    -in #{directory}#{name}.crt`
end

# Being exectuted from the root dir
def generate_test_creds
  fixture_dir = "spec/fixtures/"
  stale_cred_files = ["test_client.key", "test_client.crt", "test_client.jks", "test_client.p12",
                      "test_server.key", "test_server.crt", "test_server.jks", "test_server.p12"]

  # Remove all the old certs and keyfiles
  stale_cred_files.each do |filename|
    `rm #{fixture_dir}#{filename}`
  end

  # Generate self signed certs from the two keys
  create_self_signed_cert(directory: fixture_dir, name: "test_server")
  create_self_signed_cert(directory: fixture_dir, name: "test_client")

  # Package the pcks12 files
  create_pkcs12(directory: fixture_dir, name: "test_client")
  create_pkcs12(directory: fixture_dir, name: "test_server")

  # Package the jks files
  create_jks(directory: fixture_dir, name: "test_client", public_name: "test_server")
  create_jks(directory: fixture_dir, name: "test_server", public_name: "test_client")
end
