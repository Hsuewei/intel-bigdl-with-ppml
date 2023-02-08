#!/bin/bash
# metadata vars
readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PW_NAMESPACE=$1
PW_SECRET_NAME=$2
PW=$3
PW_MANIFEST="${script_dir}/password/password.yaml"
mkdir -p password && cd password
#export PASSWORD=$1 #used_password_when_generate_keys
openssl genrsa -out key.txt 4096
#openssl rsautl -inkey key.txt -encrypt 1>output.bin 0< <(echo -n ${PW})
openssl pkeyutl -inkey key.txt -encrypt 1>output.bin 0< <(echo -n ${PW})
KEY_TXT=$(base64 -w 0 key.txt)
OUTPUT_BIN=$(base64 -w 0 output.bin)

cat > ${PW_MANIFEST} <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $PW_SECRET_NAME
  namespace: $PW_NAMESPACE
type: Opaque
data:
  key.txt: $KEY_TXT
  output.bin: $OUTPUT_BIN
EOF
