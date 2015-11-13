#!/bin/bash

set -e

SCRIPT_ROOT=$(cd "$(dirname "$0")/.."; pwd)

MODE=DecryptMessage

while getopts "el:i:k:p:n:t" arg; do
  case $arg in
    e)
      MODE=EncryptSOAPDocument
      ;;
    l)
      LOGFILE=$OPTARG
      ;;
    i)
      INFILE=$OPTARG
      ;;
    k)
      KEYFILE=$OPTARG
      ;;
    p)
      KEYPASS=$OPTARG
      ;;
    n)
      REQNAME=$OPTARG
      ;;
    t)
      DECRYPT_IGNORE_TIMESTAMP="-Ddecrypt_ignore_wsse_timestamp=true"
      ;;
  esac
done

# Validate a bunch of parameters.
[ -z "$INFILE" ] && echo "Specify infile in -i" >&2 && exit 1
[ -z "$KEYFILE" ] && echo "Specify keyfile in -k" >&2 && exit 1
[ -z "$KEYPASS" ] && echo "Specify keypass in -p" >&2 && exit 1

MY_CLASSPATH="${SCRIPT_ROOT}/classes:${SCRIPT_ROOT}/lib/*:${SCRIPT_ROOT}/lib:${SCRIPT_ROOT}/src/main/properties" 

if [ "$MODE" = EncryptSOAPDocument ]; then
  [ -z "$REQNAME" ] && echo "Specify request name in -n" >&2 && exit 1
  LOGFILE="/tmp/vbms_encrypt.log"
  ARG="$REQNAME"
elif [ "$MODE" = DecryptMessage ]; then
  LOGFILE="/tmp/vbms_decrypt.log"
else
  echo "Unknown Mode...how did that happen??" >&2
  exit 1
fi

# To activate debug logging for WSSE encryption and decryption, edit the lib/log4j.properties file to read
#   log4j.rootCategory=DEBUG, R
# instead of ERROR, R. This will write out debug messages. Otherwise, it will write only ERROR messages
# which means the files will still exist on your filesystem, but they will be blank.

LOGFILE_ARG="-Dlogfilename=${LOGFILE}"

CMD="java -classpath $MY_CLASSPATH $LOGFILE_ARG $DECRYPT_IGNORE_TIMESTAMP $MODE $INFILE $KEYFILE $KEYPASS $ARG"
echo "Command: $CMD" >&2
exec $CMD
