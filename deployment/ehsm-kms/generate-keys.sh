#!/bin/bash
SSL_NAMESPACE=$1
SSL_SECRET_NAME=$2
SSL_SRC_PASS=$3
KEYS_MANIFEST="keys.yaml"

mkdir -p keys && cd keys
: <<CommentBlock
# rsa version
openssl req \
    -new \
    -newkey rsa:4096 \
    -days 9999 \
    -nodes \
    -x509 \
    -subj "/C=TW/ST=NewTaipei/L=Linkou/O=QCT/CN=openlab" \
    -keyout server.key \
    -out server.crt
CommentBlock

# ECDSA version
openssl req \
    -new \
    -newkey ec \
    -pkeyopt ec_paramgen_curve:prime256v1 \
    -days 9999 \
    -nodes \
    -x509 \
    -subj "/C=TW/ST=NewTaipei/L=Linkou/O=QCT/CN=openlab" \
    -keyout server.key \
    -out server.crt

cat server.key | sudo tee server.pem
cat server.crt | sudo tee -a server.pem

##
# step 1
openssl pkcs12 -export -in server.pem -out keystore.pkcs12 -passout pass:${SSL_SRC_PASS}
#openssl pkcs12 -export -in server.pem -out keystore.pkcs12 -password pass:qctRD3
# 兩者有何分別?
# https://www.openssl.org/docs/man1.0.2/man1/openssl.html
# 搜尋 PASS PHRASE ARGUMENTS

# step 2
#-storepass > destination keystore password
# -storepass 目前隨意給
#-srcstorepass > source keystore password
# -srcstorepass 需要與 step 1 給的 passout 一樣
keytool -importkeystore -srckeystore keystore.pkcs12 -destkeystore keystore.jks -srcstoretype PKCS12 -deststoretype JKS -storepass P@ssw0rd -srcstorepass ${SSL_SRC_PASS}
# keytool binary 在 rocky9 預設在 /etc/alternatives/jre/bin 之下

# 需與 step 1 與 step 2 的 -srcstorepass 一樣
# 否則: Mac verify error: invalid password?
#openssl pkcs12 -in keystore.pkcs12 -nodes -out server.pem -passout pass:qctRD3
# prompt >>> Enter Import Password:
openssl pkcs12 -in keystore.pkcs12 -nodes -out server.pem -password pass:${SSL_SRC_PASS}
# 沒有 prompt
#openssl pkcs12 -in keystore.pkcs12 -nodes -out server.pem -passin pass:qctRD3
# 沒有 prompt
##

# 兩種: rsa 或 ECDSA
# openssl rsa -in server.pem -out server.key
openssl ec -in server.pem -out server.key

openssl x509 -in server.pem -out server.crt


KEYSTORE_JKS=$(base64 -w 0 keystore.jks)
KEYSTORE_PKCS12=$(base64 -w 0 keystore.pkcs12)
SERVER_PEM=$(base64 -w 0 server.pem)
SERVER_KEY=$(base64 -w 0 server.key)
cat > ${KEYS_MANIFEST} <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SSL_SECRET_NAME
  namespace: $SSL_NAMESPACE
type: Opaque
data:
  keystore.jks: $KEYSTORE_JKS
  keystore.pkcs12: $KEYSTORE_PKCS12 
  server.pem: $SERVER_PEM
  server.key: $SERVER_KEY
EOF


