#!/bin/bash
set -e
set -x
# this script is meant to be run from the project's /script folder
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function ask_for_overwrite {
  if [ -f "$DIR/../spec/fixtures/$2" ] ; then
    read -p "Overwrite existing $2? [y/n]" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      rm "$DIR/../spec/fixtures/$2"
      mv $1 "$DIR/../spec/fixtures/$2"
    fi
  else
    mv $1 "$DIR/../spec/fixtures/$2"
  fi
}

# generate import (client) key
openssl genrsa -des3 -out import.key -passout pass:importkey 2048
openssl req -new -key import.key -out import.csr \
  -subj "/C=US/ST=Washington/L=DC/O=USDS/CN=client.vbms.va.gov" \
  -passin pass:importkey
openssl x509 -req \
  -days 365 \
  -in import.csr \
  -signkey import.key \
  -out import.crt \
  -passin pass:importkey \
  -sha256

# generate server key
openssl req \
    -new \
    -newkey rsa:2048 \
    -days 365 \
    -nodes \
    -x509 \
    -subj "/C=US/ST=Washington/L=DC/O=USDS/CN=test.vbms.va.gov" \
    -keyout server.key \
    -out server.crt \
    -sha256


# export import (client) keystore
openssl pkcs12 -export -name importkey -in "$DIR/import.crt" \
  -inkey "$DIR/import.key" -out "$DIR/keystore.p12" \
  -passin pass:importkey \
  -passout pass:importkey

keytool -importkeystore \
  -destkeystore "$DIR/keystore.jks" \
  -srckeystore "$DIR/keystore.p12" \
  -srcstoretype pkcs12 \
  -alias importkey \
  -storepass "importkey"

# move import keystore
ask_for_overwrite keystore.p12 test_keystore_importkey.p12

keytool -importcert \
  -keystore "$DIR/keystore.jks" \
  -file "$DIR/server.crt" \
  -storepass "importkey" \
  -alias "vbms_server_cert"

# import server key
openssl pkcs12 -export -name vbms_server_key -in "$DIR/server.crt" -inkey "$DIR/server.key" \
  -out "$DIR/keystore.p12"
keytool -importkeystore -destkeystore "$DIR/keystore.jks" -srckeystore "$DIR/keystore.p12" \
  -srcstoretype pkcs12 -alias "vbms_server_key" -storepass "importkey"

# move server keystore
ask_for_overwrite keystore.p12 test_keystore_vbms_server_key.p12

# move server cert
ask_for_overwrite server.crt test_server.crt

# move java keystore
ask_for_overwrite keystore.jks test_keystore.jks

# move server private key
ask_for_overwrite server.key test_server_key.key

# cleanup
rm -f import.crt import.csr import.key

echo "*****************************************************"
echo "*****************************************************"
echo "CURRENT KEYSTORE INFO:"
keytool -list -v -keystore "$DIR/../spec/fixtures/test_keystore.jks"