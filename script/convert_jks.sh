#!/bin/bash
set -e
set -x
# this script is meant to be run from the project's /script folder
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

usage() { echo "Usage: -j jksfile -p p12file -c certfile -a alias -k password"; exit 1; }

while getopts "a:j:p:c:k:h" opt; do
  case $opt in
    j)
      JKS_FILE=$OPTARG
      ;;
    p)
      P12_FILE=$OPTARG
      ;;
    c)
      CERT_FILE=$OPTARG
      ;;
    a)
      ALIAS=$OPTARG
      ;;
    k)
      # They use same password for both
      STORE_PASSWORD=$OPTARG;
      PASSWORD=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      usage
      ;;
  esac
done

if [ -z "$JKS_FILE" -o -z "$P12_FILE" -o -z "$CERT_FILE" ] ; then
  usage
fi

# converting to PKCS12
keytool -importkeystore \
  -srckeystore $JKS_FILE \
  -destkeystore $P12_FILE \
  -srcstoretype JKS \
  -deststoretype PKCS12 \
  -srcstorepass $STORE_PASSWORD \
  -deststorepass $STORE_PASSWORD \
  -srcalias $ALIAS \
  -destalias $ALIAS \
  -srckeypass $PASSWORD \
  -destkeypass $PASSWORD \
  -noprompt

# dump the certificate
echo "Dumping the certificate"
keytool -export \
  -srcalias vbms_server_key \
  -rfc \
  -file $CERT_FILE \
  -keystore $JKS_FILE \
  -srcstorepass $PASSWORD \
  -deststorepass $PASSWORD \
  -destalias vbms_server_key
