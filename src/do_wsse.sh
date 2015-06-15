#!/bin/bash

set -e

SCRIPT_ROOT=$(cd "$(dirname "$0")/.."; pwd)
echo $SCRIPT_ROOT

MODE=DecryptMessage

while getopts "ei:l:k:p:" arg; do
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
  esac
done

# Validate a bunch of parameters.
[ -z "$INFILE" ] && echo "Specify infile in -i" && exit 1
[ -z "$KEYFILE" ] && echo "Specify keyfile in -i" && exit 1
[ -z "$KEYPASS" ] && echo "Specify keypass in -p" && exit 1

MY_CLASSPATH="${SCRIPT_ROOT}/classes:${SCRIPT_ROOT}/lib/*:${SCRIPT_ROOT}/lib:${SCRIPT_ROOT}/src/main/properties" 

if [ "$MODE" = EncryptSOAPDocument ]; then
  [ -z "$REQNAME" ] && echo "Specify request name in -n" && exit 1
  ARG="$REQNAME"
  JAVA_ARGS="-Dlogfilename=${SCRIPT_ROOT}/log/upload.log"
elif[ "$MODE" = DecryptMessage ]; then
  [ -z "$LOGFILE" ] && echo "Specify outfile with -l" && exit 1
  ARG="$LOGFILE"
  JAVA_ARGS="-Dlogfilename=${LOGFILE}"
else
  echo "Unknown Mode...how did that happen??"
  exit 1
fi

java -classpath "$MY_CLASSPATH" "$JAVA_ARGS" "$MODE" "$INFILE" "$KEYFILE" "$KEYPASS" "$ARG"

