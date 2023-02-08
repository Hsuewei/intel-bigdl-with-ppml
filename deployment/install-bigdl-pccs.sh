#!/bin/bash
# Please do not use the same real IPs as nodes
#export httpsProxyUrl=your_usable_https_proxy_url
# SBX Intel® Software Guard Extensions Registration Service
#export apiKey=""
# Intel® Software Guard Extensions Registration Service
export apiKey="c10a161b3d3847d4a886d880f6e0fe77"
#export apiKey="020f95229906479e85b7c5cd3fafb629"

export appNamespace="bigdl-alan"
export pccsUserPassword="admin@QCT"
export pccsAdminPassword="admin@QCT"
export pccsCommonName="pccs"
export pccsSvcName="${pccsCommonName}-svc"
export pccsSvcPort="18081"
export pccsStsName="${pccsCommonName}-sts"
export pccsImageName="docker.io/intelanalytics/pccs:0.3.0-SNAPSHOT"
#export pccsServerNode="wn11.openlab"
export pccsServerNode="adm01.openlab"
# SSl info
export ssl_countryName="TW"
export ssl_cityName="NewTaipei"
export ssl_organizaitonName="QCT"
export ssl_commonName="openlab"
export ssl_emailAddress="alan@qct.io"
export ssl_password="qctRD3" 

# create a series of kubernetes manifest
tmpfile=$(mktemp /tmp/ID.XXXXXXX)
exec 6> "$tmpfile"
exec 7< "$tmpfile"
rm "$tmpfile"

cat << end_of_manifest 1>&6
apiVersion: v1
kind: Namespace
metadata:
  name: $appNamespace
---
apiVersion: v1
kind: Service
metadata:
  name: $pccsSvcName
  namespace: $appNamespace
  labels:
    app: $pccsCommonName
spec:
  type: ClusterIP
  ports:
    - name: $pccsCommonName
      port: $pccsSvcPort
      targetPort: $pccsSvcPort
  selector:
    app: $pccsCommonName
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pccs-configmap
  namespace: $appNamespace
data:
  pccs_entrypoint_sh: |
    #!/bin/bash
    PCCS_PORT=\$PCCS_PORT
    API_KEY=\$API_KEY
    HTTPS_PROXY_URL=\$HTTPS_PROXY_URL
    # Step 1. Generate certificates to use with PCCS
    mkdir /opt/intel/pccs/ssl_key
    cd /opt/intel/pccs/ssl_key
    openssl genrsa -out private.pem 2048
    openssl req -new -key private.pem -out csr.pem \
            -subj "/C=\$COUNTRY_NAME/ST=\$CITY_NAME/L=\$CITY_NAME/O=\$ORGANIZATION_NAME/OU=\$ORGANIZATION_NAME/CN=\$COMMON_NAME/emailAddress=\$EMAIL_ADDRESS/" -passout pass:\$PASSWORD -passout pass:\$PASSWORD
    openssl x509 -req -days 365 -in csr.pem -signkey private.pem -out file.crt
    rm -rf csr.pem
    chmod 644 ../ssl_key/*
    ls ../ssl_key
    
    # Step 2. Set default.json to be under ssl_key folder and fill the parameters
    cd /opt/intel/pccs/config/
    
    userTokenHash=\$(echo -n "\${USER_PASSWORD}" | sha512sum | tr -d '[:space:]-')
    adminTokenHash=\$(echo -n "\${ADMIN_PASSWORD}" | sha512sum | tr -d '[:space:]-')
    HOST_IP=0.0.0.0
    
    sed -i "s/YOUR_HTTPS_PORT/\$PCCS_PORT/g" default.json
    sed -i "s/YOUR_HOST_IP/\$HOST_IP/g" default.json
    sed -i 's@YOUR_PROXY@'"\$HTTPS_PROXY_URL"'@' default.json
    sed -i "s/YOUR_USER_TOKEN_HASH/\$userTokenHash/g" default.json
    sed -i "s/YOUR_ADMIN_TOKEN_HASH/\$adminTokenHash/g" default.json
    sed -i "s/YOUR_API_KEY/\$API_KEY/g" default.json
    chmod 644 default.json
    cd /opt/intel/pccs/
    
    # Step 3. Start PCCS service and keep listening
    /usr/bin/node -r esm pccs_server.js
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $pccsStsName
  namespace: $appNamespace
spec:
  selector:
    matchLabels:
      app: $pccsCommonName
  serviceName: "$pccsSvcName"
  replicas: 1
  template:
    metadata:
      labels:
        app: $pccsCommonName
    spec:
      tolerations:
      - key: ""
        operator: "Exists"
      nodeSelector:
        kubernetes.io/hostname: $pccsServerNode
      volumes:
      - name: pccs-entrypoint-sh
        configMap:
          name: pccs-configmap
          defaultMode: 0755
      containers:
      - name: $pccsCommonName
        image: "$pccsImageName"
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: pccs-entrypoint-sh
          mountPath: /opt/intel/pccs/entrypoint.sh
          subPath: pccs_entrypoint_sh
        env:
        - name: API_KEY
          value: "$apiKey"
        - name: PCCS_PORT
          value: "$pccsSvcPort"
        - name: COUNTRY_NAME
          value: "$ssl_countryName"
        - name: CITY_NAME
          value: "$ssl_cityName"
        - name: ORGANIZATION_NAME
          value: "$ssl_organizaitonName"
        - name: COMMON_NAME
          value: "$ssl_commonName"
        - name: EMAIL_ADDRESS
          value: "$ssl_emailAddress"
        - name: PASSWORD
          value: "$ssl_password"
        - name: USER_PASSWORD
          value: "$pccsUserPassword"
        - name: ADMIN_PASSWORD
          value: "$pccsAdminPassword"
        ports:
        - containerPort: $pccsSvcPort
          name: pccs-port
---
end_of_manifest
kubectl apply -f - <&7

exec 6>&-
exec 7<&-
