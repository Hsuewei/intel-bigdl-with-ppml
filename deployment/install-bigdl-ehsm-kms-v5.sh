#!/bin/bash

# metadata vars
readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# an array of SGX-enabled nodes in kuberntes
declare -a SGX_NODES
SGX_NODES=("wn11.openlab" "wn21.openlab" "wn22.openlab")

###
# ehsm-kms related vars
###
export appNamespace="bigdl-alan"
export couchdbRootUsername="YWRtaW4="
export couchdbRootPassword="YWRtaW4="
export plain_couchdbRootUsername="$(echo -n ${couchdbRootUsername} | base64 -d)"
export plain_couchdbRootPassword="$(echo -n ${couchdbRootPassword} | base64 -d)"
export storageClassName="gfs-user"
export sharedVolumeClaimName="ehsm-shared-volume-claim"
export sharedVolumeName="ehsm-shared-volume"
export dkeyserverImageName="docker.io/intelccc/ehsm_dkeyserver-dev:0.3.2"
export couchdbImageName="docker.io/library/couchdb:3.2"
export dkeycacheImageName="docker.io/intelccc/ehsm_dkeycache-dev:0.3.2"
export ehsmKmsImageName="docker.io/intelccc/ehsm_kms_service-dev:0.3.2"
#export kmsUtilsImageName="docker.io/intelanalytics/kms-utils:2.1.0"

#export kmsIP=your_kms_ip_to_use_as
#export dkeyserverNodeName=the_fixed_node_you_want_to_assign_dkeyserver_to #kubectl get nodes, and choose one
# 20230103 alan
# could be an array of nodes with:
# - sgx-related bios settings are done 
# - sgx modules loaded
# - aesmd.service is started
# And randomly selected from these nodes
# however, bigdl-ehsm-kms-deployment and dekeycache have to co-locate on the same node
# because bigdl-ehsm-kms-deployment need /var/run/{dkeyprovision.sock,dkey.bin} which is generated from dekeycache
# and dkeycache can only use hostPath volume to mount dkeyprovision.sock file
export dkeyserverNodeName="wn11.openlab"
# randomly selected from an array of nodes
#export dkeyserverNodeName=${SGX_NODES[ $RANDOM % ${#SGX_NODES[@]} ]}
export dkeyserverCommonName="dkeyserver"
export dkeyserverStsName="${dkeyserverCommonName}-sts"
export dkeyserverSvcName="${dkeyserverCommonName}-svc"
export dkeyserverPort="8888"
export couchdbCommonName="couchdb"
export couchdbStsName="${couchdbCommonName}-sts"
export couchdbSvcName="${couchdbCommonName}-svc"
export couchdbJobName="${couchdbCommonName}-jobs"
export couchdbPort="5984"
export ehsmKmsCommonName="bigdl-ehsm-kms"
export ehsmKmsSvcName="${ehsmKmsCommonName}-svc"
export ehsmKmsDplName="${ehsmKmsCommonName}-dpl"
export ehsmKmsPort="9000"
export dkeycacheCommonName="dkeycache"
export dkeycacheDplName="${dkeycacheCommonName}-dpl"
export dkeycacheSvcName="${dkeycacheCommonName}-svc"
pccsIP=$(kubectl get svc -n ${appNamespace} | grep pccs | awk '{print($3)}')
pccsPort="18081"


###
# client side vars
###
export enableAttestation="true"
export clientNamespace="jhub-alan"
export clientSaName="spark"
export clientSaSecretName="${clientSaName}-token"
export clientClusterRoleBindingName="${clientSaName}-role"
export clientSslKeysSecretName="${clientSaName}-ssl-keys-secret"
export clientSslSrcKeystorePassword="qctRD3"
export clientSslDestKeystorePassword="qctRD3sk"
export clientAuthPasswordSecretName="${clientSaName}-auth-password-secret"
export clientAuthPassword="admin@QCT"
export clientLiteralAuthPasswordSecretName="literal-${clientAuthPasswordSecretName}"

export clientKubeConfigContextName="${clientSaName}-user"
export clientPvcName="client-pvc"
export clientSharedVolName="client-vol"
export clientConfigMapName="client-cm"

# randomly selected from a list of nodes
export clientNodeName=${SGX_NODES[ $RANDOM % ${#SGX_NODES[@]} ]}
#export clientNodeName="wn21.openlab"
#export clientNodeName="wn22.openlab"



export clientAppImageName="docker.io/intelanalytics/bigdl-ppml-trusted-big-data-ml-python-gramine-reference:2.2.0-SNAPSHOT"
#export clientAppImageName="docker.io/intelanalytics/bigdl-ppml-trusted-big-data-ml-python-gramine-reference:2.2.1-SNAPSHOT"
export clientAppImageNameTest="docker.io/intelanalytics/bigdl-ppml-trusted-big-data-ml-python-gramine-reference:2.2.1-alan"


export clientAppCommonName="spark-gramine"
export clientAppSvcName="${clientAppCommonName}-svc"
export clientAppDplName="${clientAppCommonName}-dpl"
export clientAppJobName="${clientAppCommonName}-jobs"
export clientAppPort="6655"
#export clientAppSideCarName="${clientAppCommonName}-kms-utils"
export clientKmsDefaultType="ehsm"
#export kmsDefaultType="azure"
#export kmsDefaultType="simple"
export clientKmsUtilsImageName="docker.io/intelanalytics/kms-utils:0.3.0-SNAPSHOT"
#export clientEhsmAttestCommonName="ehsm-attest"
#export clientEhsmAttestJobName="${clientEhsmAttestCommonName}-jobs"
#export cleintEhsmAttestAppName="${clientEhsmAttestCommonName}-gramine"
#export clientEhsmAttestImageName="${clientAppImageName}"
export clientEhsmAttestChallengeString=$(echo -n "foo-bar" | base64)
export workloadOutputPath="/ppml/trusted-big-data-ml/workload-results"



# deletion
ACTION=$1
if [[ "${ACTION}" == "undo-server" ]]; then
  kubectl delete svc "${couchdbSvcName}" -n "${appNamespace}" --force
  kubectl delete svc "${ehsmKmsSvcName}" -n "${appNamespace}" --force
  kubectl delete svc "${dkeyserverSvcName}" -n "${appNamespace}" --force
  kubectl delete deployment "${ehsmKmsDplName}" -n "${appNamespace}" --force
  kubectl delete cm ehsm-configmap -n "${appNamespace}" --force
  kubectl delete secret ehsm-secret -n "${appNamespace}" --force
  kubectl delete deployment "${dkeycacheDplName}" -n "${appNamespace}" --force
  #kubectl delete deployment kms-utils -n "${appNamespace}" --force
  kubectl delete statefulsets.apps "${couchdbStsName}" -n "${appNamespace}" --force
  kubectl delete statefulsets.apps "${dkeyserverStsName}" -n "${appNamespace}" --force
  #kubectl delete job "${ehsmAttestJobName}" -n "${appNamespace}"
  kubectl delete job "${couchdbJobName}" -n "${appNamespace}" --force
  kubectl get pvc -n "${appNamespace}" | awk -v ns="${appNamespace}" '{if(NR!=1){system("kubectl delete pvc "$1" -n "ns)}}'
  kubectl get pv | grep "${appNamespace}" | awk '{system("kubectl delete pv "$1)}'
  kubectl get svc -n "${appNamespace}" | grep glusterfs | awk -v ns="${appNamespace}" '{system("kubectl delete svc "$1" -n "ns)}' 
  exit 0;
fi



if [[ "${ACTION}" == "undo-client" ]]; then
  kubectl delete svc $clientAppSvcName -n "${clientNamespace}" --force
  kubectl delete cm $clientConfigMapName -n "${clientNamespace}" --force
  kubectl delete deployment $clientAppDplName -n "${clientNamespace}" --force
  kubectl delete job $clientAppJobName -n "${clientNamespace}" --force
  kubectl delete serviceaccount $clientSaName -n "${clientNamespace}" --force
  kubectl delete secret $clientSaSecretName -n "${clientNamespace}" --force
  kubectl delete secret $clientSslKeysSecretName -n "${clientNamespace}" --force
  kubectl delete secret $clientAuthPasswordSecretName -n "${clientNamespace}" --force
  kubectl delete secret $clientLiteralAuthPasswordSecretName -n "${clientNamespace}" --force
  kubectl delete ClusterRoleBinding $clientClusterRoleBindingName --force
  kubectl get pvc -n "${clientNamespace}" | awk -v ns="${clientNamespace}" '{if(NR!=1){system("kubectl delete pvc "$1" -n "ns)}}'
  kubectl get pv | grep "${clientNamespace}" | awk '{system("kubectl delete pv "$1)}'
  kubectl get svc -n "${clientNamespace}" | grep glusterfs | awk -v ns="${clientNamespace}" '{system("kubectl delete svc "$1" -n "ns)}'
  kubectl delete ns $clientNamespace
  rm -rf ${script_dir}/password;
  rm -rf ${script_dir}/keys;
  exit 0;
fi



# label nodes:
## - sgx modules loaded
## - aesmd.service is started
kubectl label nodes $dkeyserverNodeName dkeyservernode=true


# create a series of kubernetes manifest
tmpfile=$(mktemp /tmp/ID.XXXXXXX)
exec 6> "$tmpfile"
exec 7< "$tmpfile"
rm "$tmpfile"
## couchdb secret 
cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: Secret
metadata:
    name: ehsm-secret
    namespace: $appNamespace
type: Opaque
data:
    couch_root_username: $couchdbRootUsername
    couch_root_password: $couchdbRootPassword
end_of_manifest
kubectl apply -f - <&7

## pvc
cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $sharedVolumeClaimName
  namespace: $appNamespace
spec:
  accessModes:
  - "ReadWriteOnce"
  volumeMode: Filesystem
  resources:
    requests:
      storage: 4Gi
  storageClassName: "$storageClassName"
end_of_manifest
kubectl apply -f - <&7

## dkeyserver service
cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: Service
metadata:
  name: $dkeyserverSvcName
  namespace: $appNamespace
  labels:
    app: $dkeyserverSvcName
spec:
  type: ClusterIP
  ports:
    - name: $dkeyserverSvcName
      port: $dkeyserverPort
      targetPort: $dkeyserverPort
  selector:
    app: $dkeyserverSvcName
end_of_manifest
kubectl apply -f - <&7

## couchdb service
cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: Service
metadata:
  name: $couchdbSvcName
  namespace: $appNamespace
  labels:
    app: $couchdbSvcName
spec:
  type: ClusterIP
  ports:
    - name: $couchdbSvcName
      port: $couchdbPort
      targetPort: $couchdbPort
  selector:
    app: $couchdbSvcName
end_of_manifest
kubectl apply -f - <&7


# ehsm-kms service
cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: Service
metadata:
  name: $ehsmKmsSvcName
  namespace: $appNamespace
spec:
  type: ClusterIP
  selector:
    app: $ehsmKmsCommonName
  ports:
    - name: $ehsmKmsCommonName
      protocol: TCP
      port: $ehsmKmsPort
  sessionAffinity: ClientIP
end_of_manifest
kubectl apply -f - <&7


#####
couchdbSvcIP=$(kubectl get svc -n ${appNamespace} | grep ${couchdbSvcName} | awk '{print($3)}')
dkeyserverSvcIP=$(kubectl get svc -n ${appNamespace} | grep ${dkeyserverSvcName} | awk '{print($3)}')
ehsmKmsSvcIP=$(kubectl get svc -n ${appNamespace} | grep ${ehsmKmsSvcName} | awk '{print($3)}') 

#####

## ehsm configmap
cat << end_of_manifest 1>&6
apiVersion: v1
kind: ConfigMap
metadata:
  name: ehsm-configmap
  namespace: $appNamespace
data:
  dkeyserver_resolv_conf: |
    nameserver 10.96.0.10
    options ndots: 5
  database_url: "$couchdbSvcIP"
  database_port: "$couchdbPort"
  database_name: "ehsm_kms_db"
  dkeyserver_ip: "$dkeyserverSvcIP"
  dkeyserver_port: "$dkeyserverPort"
  pccs_url: "https://$pccsIP:$pccsPort"
  sgx_default_qcnl.conf: |
    {
      "pccs_url": "https://$pccsIP:$pccsPort/sgx/certification/v3/",
      "use_secure_cert": false,
      "retry_times": 6,
      "retry_delay": 10,
      "pck_cache_expire_hours": 168
    }
  prep_on_dkeyserver_sh: |
    #!/bin/bash
    chmod 666 /home/ehsm/out/ehsm-dkeyserver/libenclave-ehsm-dkeyserver.so 1>>/var/run/ehsm/logs/dkeyserver-startup.log 2>&1
    chmod 666 /home/ehsm/out/ehsm-dkeyserver/libenclave-ehsm-dkeyserver.signed.so 1>>/var/run/ehsm/logs/dkeyserver-startup.log 2>&1
    if [ -c "/dev/sgx/enclave" ]; then 
      echo "/dev/sgx/enclave is ready" | tee -a /var/run/ehsm/logs/dkeyserver-startup.log;
    elif [ -c "/dev/sgx_enclave" ]; then
      echo "/dev/sgx/enclave not ready, try to link to /dev/sgx_enclave" | tee -a /var/run/ehsm/logs/dkeyserver-startup.log
      mkdir -p /dev/sgx;
      ln -s /dev/sgx_enclave /dev/sgx/enclave;
    else
      echo "both /dev/sgx/enclave /dev/sgx_enclave are not ready, please check the kernel and driver" | tee -a /var/run/ehsm/logs/dkeyserver-startup.log
    fi
    if [ -c "/dev/sgx/provision" ]; then
      echo "/dev/sgx/provision is ready" | tee -a /var/run/ehsm/logs/dkeyserver-startup.log;
    elif [ -c "/dev/sgx_provision" ]; then
      echo "/dev/sgx/provision not ready, try to link to /dev/sgx_provision" | tee -a /var/run/ehsm/logs/dkeyserver-startup.log
      mkdir -p /dev/sgx;
      ln -s /dev/sgx_provision /dev/sgx/provision;
    else
      echo "both /dev/sgx/provision /dev/sgx_provision are not ready, please check the kernel and driver" | tee -a /var/run/ehsm/logs/dkeyserver-startup.log;
    fi;
    echo "done surveying sgx related modules" | tee -a /var/run/ehsm/logs/dkeyserver-startup.log;
    sleep 5;
  prep_on_dkeycache_sh: |
    #!/bin/bash
    if [ -c "/dev/sgx/enclave" ]; then 
      echo "/dev/sgx/enclave is ready" | tee -a /var/run/ehsm/logs/dkeycache-startup.log;
    elif [ -c "/dev/sgx_enclave" ]; then
      echo "/dev/sgx/enclave not ready, try to link to /dev/sgx_enclave" | tee -a /var/run/ehsm/logs/dkeycache-startup.log
      mkdir -p /dev/sgx;
      ln -s /dev/sgx_enclave /dev/sgx/enclave;
    else
      echo "both /dev/sgx/enclave /dev/sgx_enclave are not ready, please check the kernel and driver" | tee -a /var/run/ehsm/logs/dkeycache-startup.log
    fi
    if [ -c "/dev/sgx/provision" ]; then
      echo "/dev/sgx/provision is ready" | tee -a /var/run/ehsm/logs/dkeycache-startup.log;
    elif [ -c "/dev/sgx_provision" ]; then
      echo "/dev/sgx/provision not ready, try to link to /dev/sgx_provision" | tee -a /var/run/ehsm/logs/dkeycache-startup.log;
      mkdir -p /dev/sgx;
      ln -s /dev/sgx_provision /dev/sgx/provision;
    else
      echo "both /dev/sgx/provision /dev/sgx_provision are not ready, please check the kernel and driver" | tee -a /var/run/ehsm/logs/dkeycache-startup.log;
    fi;
    echo "done surveying sgx related modules" | tee -a /var/run/ehsm/logs/dkeycache-startup.log;
    sleep 5;
---
end_of_manifest
kubectl apply -f - <&7

## dkeyserver statefulset
cat << end_of_manifest 1>&6
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $dkeyserverStsName
  namespace: $appNamespace
spec:
  selector:
    matchLabels:
      app: $dkeyserverSvcName
  serviceName: "$dkeyserverSvcName"
  replicas: 1
  template:
    metadata:
      labels:
        app: $dkeyserverSvcName
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$dkeyserverNodeName"
        dkeyservernode: "true"
      volumes:
      - name: prep-on-dkeyserver-sh
        configMap:
          name: ehsm-configmap
          defaultMode: 0755
      - name: sgx-default-qcnl-file
        configMap:
          name: ehsm-configmap
      - name: dev-enclave
        hostPath:
          path: /dev/sgx/enclave
      - name: dev-provision
        hostPath:
          path: /dev/sgx/provision
      - name: dev-aesmd
        hostPath:
          path: /var/run/aesmd
      - name: $sharedVolumeName
        persistentVolumeClaim:
          claimName: $sharedVolumeClaimName
      - name: dev-dkeyprovision
        hostPath:
          path: /var/run/ehsm
      - name: dkeyserver-resolv-file
        configMap:
          name: ehsm-configmap
      containers:
      - name: $dkeyserverCommonName
        image: $dkeyserverImageName
        securityContext:
          privileged: true
        imagePullPolicy: IfNotPresent
        lifecycle:
          postStart:
            exec:
              command:
              #- '/bin/bash'
              #- '/home/ehsm/out/ehsm-dkeyserver/prep_on_dkeyserver.sh'
              command: ['/bin/bash', '-c', 'chmod 666 /home/ehsm/out/ehsm-dkeyserver/libenclave-ehsm-dkeyserver.s*; if [ -c "/dev/sgx/enclave" ]; then echo "/dev/sgx/enclave is ready";elif [ -c "/dev/sgx_enclave" ]; then echo "/dev/sgx/enclave not ready, try to link to /dev/sgx_enclave"; mkdir -p /dev/sgx; ln -s /dev/sgx_enclave /dev/sgx/enclave; else echo "both /dev/sgx/enclave /dev/sgx_enclave are not ready, please check the kernel and driver";fi; if [ -c "/dev/sgx/provision" ]; then echo "/dev/sgx/provision is ready";elif [ -c "/dev/sgx_provision" ]; then echo "/dev/sgx/provision not ready, try to link to /dev/sgx_provision";mkdir -p /dev/sgx;ln -s /dev/sgx_provision /dev/sgx/provision;else echo "both /dev/sgx/provision /dev/sgx_provision are not ready, please check the kernel and driver";fi; sleep 5;']
        command: ['/home/ehsm/out/ehsm-dkeyserver/ehsm-dkeyserver']
        args: ['-r','\$(DKEYSERVER_ROLE)']
        volumeMounts:
        - name: prep-on-dkeyserver-sh
          mountPath: /home/ehsm/out/ehsm-dkeyserver/prep-on-dkeyserver.sh
          subPath: prep_on_dkeyserver_sh
        - name: dev-dkeyprovision
        #- name: $sharedVolumeName
          mountPath: /var/run/ehsm
        - name: dev-enclave
          mountPath: /dev/sgx/enclave
        - name: dev-provision
          mountPath: /dev/sgx/provision
        - name: dev-aesmd
          mountPath: /var/run/aesmd
        - name: $sharedVolumeName
          mountPath: /etc
        - name: dkeyserver-resolv-file
          mountPath: /etc/resolv.conf
          subPath: dkeyserver_resolv_conf
        - name: sgx-default-qcnl-file
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl.conf
        env:
        - name: PCCS_URL
          value: "https://$pccsIP:$pccsPort"
        - name: DKEYSERVER_ROLE
          value: "root"
        ports:
        - containerPort: $dkeyserverPort
          name: dkeyserver-port
end_of_manifest
kubectl apply -f - <&7

# couchdb sts 
cat << end_of_manifest 1>&6
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: $couchdbStsName
  namespace: $appNamespace
spec:
  selector:
    matchLabels:
      app: $couchdbSvcName
  serviceName: "$couchdbSvcName"
  replicas: 1
  template:
    metadata:
      labels:
        app: $couchdbSvcName
    spec:
      volumes:
      - name: $sharedVolumeName
        persistentVolumeClaim:
          claimName: $sharedVolumeClaimName
      containers:
      - name: $couchdbSvcName
        image: $couchdbImageName
        imagePullPolicy: IfNotPresent
        lifecycle:
          postStart:
            exec:
              command:
              - sh
              - -c
              - "echo [couchdb] single_node=true >> /opt/couchdb/etc/local.d/docker.ini; echo [couchdb] single_node=true >> /opt/couchdb/etc/local.ini"
        readinessProbe:
          httpGet:
            port: couchdb-port
            path: /
          initialDelaySeconds: 3
          periodSeconds: 6
        ports:
        - containerPort: $couchdbPort
          name: couchdb-port
        volumeMounts:
        - name: $sharedVolumeName
          mountPath: /opt/couchdb/data
        env:
          - name: COUCHDB_USER
            valueFrom:
              secretKeyRef:
                name: ehsm-secret
                key: couch_root_username
          - name: COUCHDB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: ehsm-secret
                key: couch_root_password
end_of_manifest
kubectl apply -f - <&7



# couchdb jobs to create _users database
cat << end_of_manifest 1>&6
apiVersion: batch/v1
kind: Job
metadata:
  name: $couchdbJobName
  namespace: $appNamespace
spec:
  backoffLimit: 6
  completions: 1
  completionMode: "NonIndexed"
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: create-underlineusers-db
        image: "docker.io/curlimages/curl:7.87.0"
        imagePullPolicy: IfNotPresent
        command: ['/bin/sh']
        args: ['-c', 'until curl http://$couchdbSvcIP:$couchdbPort/; do echo waiting for couchDB; sleep 5; done; curl --request PUT http://$plain_couchdbRootUsername:$plain_couchdbRootPassword@$couchdbSvcIP:$couchdbPort/_users;']
end_of_manifest
kubectl apply -f - <&7


# dkeycahe deployment
cat << end_of_manifest 1>&6
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $dkeycacheDplName
  namespace: $appNamespace
spec:
  replicas: 1
  selector:
    matchLabels:
      name: $dkeycacheSvcName
  template:
    metadata:
      labels:
        name: $dkeycacheSvcName
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$dkeyserverNodeName"
      volumes:
      - name: prep-on-dkeycache-sh
        configMap:
          name: ehsm-configmap
          defaultMode: 0755
      - name: sgx-default-qcnl-file
        configMap:
          name: ehsm-configmap
      - name: dev-enclave
        hostPath:
          path: /dev/sgx/enclave
      - name: dev-provision
        hostPath:
          path: /dev/sgx/provision
      - name: dev-aesmd
        hostPath:
          path: /var/run/aesmd
      - name: dev-dkeyprovision
        hostPath:
          path: /var/run/ehsm
        #persistentVolumeClaim:
        #  claimName: $sharedVolumeClaimName    
      containers:
      - name: dkeycache
        image: $dkeycacheImageName
        lifecycle:
          postStart:
            exec:
              command:
              #- '/bin/bash'
              #- '/home/ehsm/out/ehsm-dkeyserver/prep_on_dkeycache.sh'
              - '/bin/bash'
              - '-c'
              - 'if [ -c "/dev/sgx/enclave" ]; then echo "/dev/sgx/enclave is ready";elif [ -c "/dev/sgx_enclave" ]; then echo "/dev/sgx/enclave not ready, try to link to /dev/sgx_enclave"; mkdir -p /dev/sgx; ln -s /dev/sgx_enclave /dev/sgx/enclave; else echo "both /dev/sgx/enclave /dev/sgx_enclave are not ready, please check the kernel and driver";fi; if [ -c "/dev/sgx/provision" ]; then echo "/dev/sgx/provision is ready";elif [ -c "/dev/sgx_provision" ]; then echo "/dev/sgx/provision not ready, try to link to /dev/sgx_provision";mkdir -p /dev/sgx;ln -s /dev/sgx_provision /dev/sgx/provision;else echo "both /dev/sgx/provision /dev/sgx_provision are not ready, please check the kernel and driver";fi;sleep 10;'
        command: ['/home/ehsm/out/ehsm-dkeycache/ehsm-dkeycache']
        args: ['-i','\$(DKEYSERVER_IP)','-p','\$(DKEYSERVER_PORT)']
        securityContext:
          privileged: true
        volumeMounts:
        - name: prep-on-dkeycache-sh
          mountPath: /home/ehsm/out/ehsm-dkeycache/prep-on-dkeycache.sh
          subPath: prep_on_dkeycache_sh
        - mountPath: /dev/sgx/enclave
          name: dev-enclave
        - mountPath: /dev/sgx/provision
          name: dev-provision
        - mountPath: /var/run/aesmd
          name: dev-aesmd
        - mountPath: /var/run/ehsm
          name: dev-dkeyprovision
        - name: sgx-default-qcnl-file
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl.conf
        env:
        - name: PCCS_URL
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: pccs_url
        - name: DKEYSERVER_IP
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: dkeyserver_ip
        - name: DKEYSERVER_PORT
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: dkeyserver_port
end_of_manifest
kubectl apply -f - <&7

# bigdl-ehsm-kms service
cat << end_of_manifest 1>&6
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $ehsmKmsDplName
  namespace: $appNamespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $ehsmKmsCommonName
  template:
    metadata:
      labels:
        app: $ehsmKmsCommonName
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$dkeyserverNodeName"
      volumes:
      - name: sgx-default-qcnl-file
        configMap:
          name: ehsm-configmap
      - name: dev-enclave
        hostPath:
          path: /dev/sgx/enclave
      - name: dev-provision
        hostPath:
          path: /dev/sgx/provision
      - name: dev-aesmd
        hostPath:
          path: /var/run/aesmd
      - name: dev-dkeyprovision
        hostPath:
          path: /var/run/ehsm
        #persistentVolumeClaim:
        #  claimName: $sharedVolumeClaimName
      initContainers:
      - name: init-bigdl-ehsm-kms
        image: $ehsmKmsImageName
        imagePullPolicy: IfNotPresent
        command: ['sh' , '-c','if [ -c "/dev/sgx/enclave" ]; then echo "/dev/sgx/enclave is ready";elif [ -c "/dev/sgx_enclave" ]; then echo "/dev/sgx/enclave not ready, try to link to /dev/sgx_enclave"; mkdir -p /dev/sgx; ln -s /dev/sgx_enclave /dev/sgx/enclave; else echo "both /dev/sgx/enclave /dev/sgx_enclave are not ready, please check the kernel and driver";fi; if [ -c "/dev/sgx/provision" ]; then echo "/dev/sgx/provision is ready";elif [ -c "/dev/sgx_provision" ]; then echo "/dev/sgx/provision not ready, try to link to /dev/sgx_provision";mkdir -p /dev/sgx;ln -s /dev/sgx_provision /dev/sgx/provision;else echo "both /dev/sgx/provision /dev/sgx_provision are not ready, please check the kernel and driver";fi;until curl http://\$(EHSM_CONFIG_COUCHDB_SERVER):\$(EHSM_CONFIG_COUCHDB_PORT)/; do echo waiting for couchDB; sleep 5; done;echo "waiting for dkeycache...";sleep 20;']
        env:
        - name: EHSM_CONFIG_COUCHDB_SERVER
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: database_url
        - name: EHSM_CONFIG_COUCHDB_PORT
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: database_port
      containers:
      - name: bigdl-ehsm-kms
        # You need to tag the bigdl-ehsm-kms container image with this name on each worker node or change it to point to a docker hub to get the container image.
        image: $ehsmKmsImageName
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        # change default ENTRYPOTINT and CMD of container image
        command: ['node']
        args: ['/home/ehsm/ehsm_kms_service/ehsm_kms_server.js']
        volumeMounts:
        - name: sgx-default-qcnl-file
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl.conf
        - mountPath: /dev/sgx/enclave
          name: dev-enclave
        - mountPath: /dev/sgx/provision
          name: dev-provision
        - mountPath: /var/run/aesmd
          name: dev-aesmd
        - mountPath: /var/run/ehsm
          name: dev-dkeyprovision
        env:
        - name: PCCS_URL
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: pccs_url
        - name: EHSM_CONFIG_COUCHDB_USERNAME
          valueFrom:
            secretKeyRef:
              name: ehsm-secret
              key: couch_root_username
        - name: EHSM_CONFIG_COUCHDB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ehsm-secret
              key: couch_root_password
        - name: EHSM_CONFIG_COUCHDB_SERVER
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: database_url
        - name: EHSM_CONFIG_COUCHDB_PORT
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: database_port
        - name: EHSM_CONFIG_COUCHDB_DB
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: database_name
        ports:
        - name: ehsm-kms
          containerPort: $ehsmKmsPort
end_of_manifest
kubectl apply -f - <&7




########################################################
# works on client side
########################################################


# ehsm enrollment
## jq is needed
{ hash -r; command -V jq 1>/dev/null 2>&1;} || { echo "jq is not installed, installing now..."; dnf install -y jq;}

until curl --insecure "https://${ehsmKmsSvcIP}:${ehsmKmsPort}/ehsm?Action=GetVersion" 1>/dev/null 2>&1;
  do
    echo 'waiting for ehsm deployment being ready for enrollment......';
    sleep 5;
  done
## start enrollment
set -u; set -e;
echo 'start ehsm enrollment......';
read -r ehsmApiKey ehsmAppId 0< <({ curl --insecure --silent --get --data "Action=Enroll" \
    "https://${ehsmKmsSvcIP}:${ehsmKmsPort}/ehsm" | jq -r '(.result.apikey) + " " + (.result.appid)';})
cat << end_of_message
ehsm enrollment is done
apikey is $ehsmApiKey
appid is $ehsmAppId
end_of_message
set +u; set +e;


cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: Namespace
metadata:
  name: $clientNamespace
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $clientSaName
  namespace: $clientNamespace
---
apiVersion: v1
kind: Secret
metadata:
  name: $clientSaSecretName
  namespace: $clientNamespace
  annotations:
    kubernetes.io/service-account.name: $clientSaName
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $clientClusterRoleBindingName
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: $clientSaName
  namespace: $clientNamespace
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $clientPvcName
  namespace: $clientNamespace
spec:
  accessModes:
  - "ReadWriteOnce"
  volumeMode: Filesystem
  resources:
    requests:
      storage: 30Gi
  storageClassName: "$storageClassName"
end_of_manifest
kubectl apply -f - <&7


# gnerate spark ssl keys and password
# openssl is required
{ hash -r; command -V openssl 1>/dev/null 2>&1;} || { echo "jq is not installed, installing now..."; dnf install -y openssl;}
# invoked in subshell
(
/bin/bash \
  ${script_dir}/generate-keys.sh \
  ${clientNamespace} \
  ${clientSslKeysSecretName} \
  ${clientSslSrcKeystorePassword} \
  ${clientSslDestKeystorePassword}
)
# invoked in subshell
(
/bin/bash \
  ${script_dir}/generate-password.sh \
  ${clientNamespace} \
  ${clientAuthPasswordSecretName} \
  ${clientAuthPassword}
)


# generate client side kubeconfig
tmpfile=$(mktemp /tmp/ID.XXXXXXX)
cat /root/.kube/config > ${tmpfile}
kubectl config \
  set-credentials spark-user \
  --token=$(kubectl get secret ${clientSaSecretName} -n jhub-alan -o jsonpath={.data.token} | base64 -d) \
  --kubeconfig ${tmpfile}
kubectl config \
  set-context spark-context \
  --user=spark-user \
  --kubeconfig ${tmpfile}
read -r CLUSTER_NAME 0< <(kubectl config get-clusters --kubeconfig ${tmpfile} | sed -n '/NAME/{n;p}')
kubectl config \
  set-context spark-context \
  --cluster=${CLUSTER_NAME} \
  --user=spark-user \
  --kubeconfig ${tmpfile}
kubectl config \
  use-context spark-context \
  --kubeconfig ${tmpfile}
clientKubeConfig=$(kubectl config \
  view \
  --flatten \
  --minify \
  --kubeconfig ${tmpfile} | awk '{printf("    %s\n",$0)}')
rm -rf ${tmpfile}



cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $clientConfigMapName
  namespace: $clientNamespace
data:
  client_kubeconfig: |
$clientKubeConfig
  sgx_default_qcnl_conf: |
    {
      "pccs_url": "https://$pccsIP:$pccsPort/sgx/certification/v3/",
      "use_secure_cert": false,
      "retry_times": 6,
      "retry_delay": 10,
      "pck_cache_expire_hours": 168
    }
  generate_people_csv_py: |
    import sys
    import random
    jobs=['Developer', 'Engineer', 'Researcher']
    output_file = sys.argv[1]
    num_lines = int(sys.argv[2])
    with open(output_file, 'wb') as File:
        File.write("name,age,job\\n".encode())
        cur_num_line = 0
        num_of_developer_age_between_20_and_40 = 0
        while(cur_num_line < num_lines):
            name_length = random.randint(3, 7)
            name = ''
            for i in range(name_length):
                name += chr(random.randint(97, 122))
            age=random.randint(18, 60)
            job=jobs[random.randint(0, 2)]
            if age <= 40 and age >= 20 and job == 'Developer':
                num_of_developer_age_between_20_and_40 += 1
            line = name + ',' + str(age) + ',' + job + "\\n"
            File.write(line.encode())
            cur_num_line += 1
        print("Num of Developer age between 20,40 is " + str(num_of_developer_age_between_20_and_40))
    File.close()
  prep_on_kms_utils_sh: | 
    #!/bin/bash
    #/usr/bin/mount -o remount,exec /dev;

    export DUMMY_FILE_PATH="/home/data/people.csv"
    #export DUMMY_FILE_PATH="/home/data/cry_ah.csv"

    exec 6>&1 
    exec 7>&2
    exec 1>/home/logs/kms-startup.log 2>&1

    [[ ! -d /dev/sgx ]] && mkdir /dev/sgx;
    for i in /dev/sgx_*; do
      ! test -e "/dev/sgx/\${i##*_}" && ln -s "\$i" "/dev/sgx/\${i##*_}"
    done

    if [ -c "/dev/sgx/enclave" ]; then 
      echo "/dev/sgx/enclave is ready";
    elif [ -c "/dev/sgx_enclave" ]; then
      echo "/dev/sgx/enclave not ready, try to link to /dev/sgx_enclave" | tee -a /home/startup.log
      mkdir -p /dev/sgx;
      ln -s /dev/sgx_enclave /dev/sgx/enclave;
    else
      echo "both /dev/sgx/enclave /dev/sgx_enclave are not ready, please check the kernel and driver";
    fi
    if [ -c "/dev/sgx/provision" ]; then
      echo "/dev/sgx/provision is ready";
    elif [ -c "/dev/sgx_provision" ]; then
      echo "/dev/sgx/provision not ready, try to link to /dev/sgx_provision" | tee -a /home/startup.log
      mkdir -p /dev/sgx;
      ln -s /dev/sgx_provision /dev/sgx/provision;
    else
      echo "both /dev/sgx/provision /dev/sgx_provision are not ready, please check the kernel and driver" | tee -a /home/startup.log;
    fi;
    echo "done surveying sgx related modules" | tee -a /home/startup.log;
    echo \$'\\n' 1>>/home/startup.log;
    sleep 5;
    
    /usr/bin/chmod 755 /home/entrypoint.sh;
    
    echo "generating encryption keys under shared storage /home/key......"
    # generate keys
    bash /home/entrypoint.sh generatekeys "\${EHSM_ENROLL_APPID}" "\${EHSM_ENROLL_APIKEY}"
    
    echo "creating \${DUMMY_FILE_PATH} under shared storage /home/data, and the \${DUMMY_FILE_PATH} is created with 87 lines ......"
    # create dummy file
    /usr/bin/python3 /home/generate_people_csv.py "\${DUMMY_FILE_PATH}" 87

    echo "encrypting \${DUMMY_FILE_PATH}" 
    # encrypt dummy file
    bash /home/entrypoint.sh encrypt "\${EHSM_ENROLL_APPID}" "\${EHSM_ENROLL_APIKEY}" "\${DUMMY_FILE_PATH}"

    exec 1>&6 6>&-
    exec 2>&7 7>&-
  client_env_prep.sh: |
    #!/bin/bash
    export APP_STARTUP_LOG_PATH="/ppml/trusted-big-data-ml/logs/client-env-prep.log"

    exec 6>&1
    exec 7>&2
    exec 1>\${APP_STARTUP_LOG_PATH} 2>&1
   

    # echo commands to the terminal output
    set -ex

    # prep additional jars
    [[ -e \${ALAN_HOME}/jar_files.zip ]] && /usr/bin/unzip \${ALAN_HOME}/jar_files.zip -d \${ALAN_HOME}/jars/

    # enable spark eventLog generating
    /usr/bin/cat > \${SPARK_HOME}/conf/spark-defaults.conf << EOF
    spark.eventLog.enabled true
    spark.eventLog.dir $workloadOutputPath
    spark.history.fs.logDirectory $workloadOutputPath
    EOF

    # start spark history server
    echo "====== start spark history server ======"
    /bin/bash \${SPARK_HOME}/sbin/start-history-server.sh

      
    # path of sgx devices
    [[ ! -d /dev/sgx ]] && mkdir /dev/sgx;
    for i in /dev/sgx_*; do
      ! test -e "/dev/sgx/\${i##*_}" && ln -s "\$i" "/dev/sgx/\${i##*_}"
    done

    # attest EHSM Server
    # more info:
    # - TCB is out of date
    # https://www.intel.com/content/www/us/en/developer/articles/technical/quote-verification-attestation-with-intel-sgx-dcap.html
    JARS="\${SPARK_HOME}/jars/*:\${BIGDL_HOME}/jars/*"
    /opt/jdk8/bin/java -Xmx512m -cp "\${JARS}" com.intel.analytics.bigdl.ppml.attestation.VerificationCLI -i "\${APP_ID}" -k "\${API_KEY}" -c "\${CHALLENGE_STRING}" -u "\${ATTESTATION_URL}" -t "\${ATTESTATION_TYPE}" 2>&1 | tee -a /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_VerificationCLI_attestation.log

    # get mr_enclave and mr_mr_signer
    read -r MR_ENCLAVE MR_SIGNER 0< <({ bash /ppml/trusted-big-data-ml/init.sh | awk '{if(\$1~/mr_enclave/){mr_enclave=\$2;}if(\$1~/mr_signer/){mr_signer=\$2;}}END{print(mr_enclave,mr_signer);}';})

    # register MREnclave to EHSM and store policyID as variable
    echo 'register MREnclave to EHSM and store policyID as variable...'
    POLICY_ID=\$({ python3 /ppml/trusted-big-data-ml/register-mrenclave.py \\
                    --appid "\${APP_ID}" \\
                    --apikey "\${API_KEY}" \\
                    --url "https://\${ATTESTATION_URL}" \\
                    --mr_enclave "\${MR_ENCLAVE}" \\
                    --mr_signer "\${MR_SIGNER}" | \\
                   sed -n '/\[INFO\]\spolicyID:/{n;p}';})


    # customize spark-driver-template.yaml
    /usr/bin/cat > /ppml/trusted-big-data-ml/spark-driver-template.yaml << EOF
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: $clientNamespace
      name: spark-driver-pod
    spec:
      serviceAccountName: $clientSaName
      nodeSelector:
        kubernetes.io/hostname: "$clientNodeName"
      volumes:
      #- name: dev-enclave
      #  hostPath:
      #    path: /dev/sgx_enclave
      #- name: dev-provision
      #  hostPath:
      #    path: /dev/sgx_provision
      - name: client-cm-vol
        configMap:
          name: $clientConfigMapName
          #defaultMode: 0755
          defaultMode: 493
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: aesm-socket
        hostPath:
          path: /var/run/aesmd/aesm.socket
      - name: $clientSharedVolName
        persistentVolumeClaim:
          claimName: $clientPvcName
      - name: $clientSslKeysSecretName
        secret:
          secretName: $clientSslKeysSecretName
      containers:
      - name: spark-driver
        #image: $clientAppImageName
        #command: ['/bin/bash']
        #args: ['/opt/modified_entrypoint.sh']
        securityContext:
          privileged: true
        env:
        #- name: SGX_DRIVER_MEM_SIZE
        #  value: "7g"
        #- name: SGX_EXECUTOR_MEM_SIZE
        #  value: "7g"
        #- name: SGX_DRIVER_JVM_MEM_SIZE
        #  value: "7g"
        #- name: SGX_EXECUTOR_JVM_MEM_SIZE
        #  value: "7g"
        - name: PCCS_URL
          value: "\${PCCS_URL}"
        - name: ATTESTATION
          value: "\${ATTESTATION}"
        - name: ATTESTATION_TYPE
          value: "EHSMAttestationService"
        - name: ATTESTATION_URL
          value: "\${ATTESTATION_URL}"
        #- name: APP_ID
        - name: ATTESTATION_ID
          value: "\${APP_ID}"
        #  valueFrom:
        #    secretKeyRef:
        #      name: kms-secret
        #      key: app_id
        #- name: API_KEY
        - name: ATTESTATION_KEY
          value: "\${API_KEY}"
        #  valueFrom:
        #    secretKeyRef:
        #      name: kms-secret
        #      key: app_key
        - name: POLICY_ID
          value: "\${POLICY_ID}"
        - name: CHALLENGE_STRING
          value: "\${CHALLENGE_STRING}"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        volumeMounts:
        - name: client-cm-vol
          #mountPath: /opt/modified_entrypoint.sh
          mountPath: /opt/entrypoint.sh
          subPath: modified_entrypoint_sh
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: aesm-socket
          mountPath: /var/run/aesmd/aesm.socket
        - name: client-cm-vol
          mountPath: /root/.kube/config
          subPath: kubeconfig_conf
          readOnly: true
        - name: client-cm-vol
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl_conf
          readOnly: true
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/logs
          subPath: shared_logs_dir
        #- mountPath: /dev/sgx_enclave
        #  name: dev-enclave
        #- mountPath: /dev/sgx_provision
        #  name: dev-provision
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/work/kms_data
          subPath: kms_data
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/work/kms_key
          subPath: kms_key
        #- name: $clientAuthPasswordSecretName
        #  mountPath: /ppml/trusted-big-data-ml/work/password
        #  readOnly: true
        #- name: $clientSslKeysSecretName
        #  mountPath: /ppml/trusted-big-data-ml/work/keys
        #  readOnly: true
        - name: $clientSharedVolName
          mountPath: $workloadOutputPath
          #subPathExpr: driver-\\\$(POD_NAME)
          subPath: simplequery
        #resources:
          #requests:
            #cpu: 16
            #memory: 128Gi
            #sgx.intel.com/epc: 133258905600
            #sgx.intel.com/enclave: 10
            #sgx.intel.com/provision: 10
          #limits:
            #cpu: 16
            #memory: 128Gi
            #sgx.intel.com/epc: 133258905600
            #sgx.intel.com/enclave: 10
            #sgx.intel.com/provision: 10
    EOF

    # customize spark-executor-template.yaml
    /usr/bin/cat > /ppml/trusted-big-data-ml/spark-executor-template.yaml << EOF
    apiVersion: v1
    kind: Pod
    metadata:
      namespace: $clientNamespace
      name: spark-exexutor-pod
    spec:
      serviceAccountName: $clientSaName
      nodeSelector:
        kubernetes.io/hostname: "$clientNodeName"
      volumes:
      #- name: dev-enclave
      #  hostPath:
      #    path: /dev/sgx_enclave
      #- name: dev-provision
      #  hostPath:
      #    path: /dev/sgx_provision
      - name: client-cm-vol
        configMap:
          name: $clientConfigMapName
          #defaultMode: 0755
          defaultMode: 493 
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      - name: aesm-socket
        hostPath:
          path: /var/run/aesmd/aesm.socket
      - name: $clientSharedVolName
        persistentVolumeClaim:
          claimName: $clientPvcName
      - name: $clientSslKeysSecretName
        secret:
          secretName: $clientSslKeysSecretName
      containers:
      - name: spark-executor
        #image: $clientAppImageName
        #command: ['/bin/bash']
        #args: ['/opt/modified_entrypoint.sh']
        securityContext:
          privileged: true
        env:
        #- name: SGX_DRIVER_MEM_SIZE
        #  value: "7g"
        #- name: SGX_EXECUTOR_MEM_SIZE
        #  value: "7g"
        #- name: SGX_DRIVER_JVM_MEM_SIZE
        #  value: "7g"
        #- name: SGX_EXECUTOR_JVM_MEM_SIZE
        #  value: "7g"
        - name: PCCS_URL
          value: "\${PCCS_URL}"
        - name: ATTESTATION
          value: "\${ATTESTATION}"
        - name: ATTESTATION_TYPE
          value: "EHSMAttestationService"
        - name: ATTESTATION_URL
          value: "\${ATTESTATION_URL}"
        #- name: APP_ID
        - name: ATTESTATION_ID
          value: "\${APP_ID}"
        #  valueFrom:
        #    secretKeyRef:
        #      name: kms-secret
        #      key: app_id
        #- name: API_KEY
        - name: ATTESTATION_KEY
          value: "\${API_KEY}"
        #  valueFrom:
        #    secretKeyRef:
        #      name: kms-secret
        #      key: app_key
        - name: POLICY_ID
          value: "\${POLICY_ID}"
        - name: CHALLENGE_STRING
          value: "\${CHALLENGE_STRING}"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        volumeMounts:
        - name: client-cm-vol
          #mountPath: /opt/modified_entrypoint.sh
          mountPath: /opt/entrypoint.sh
          subPath: modified_entrypoint_sh
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
        - name: aesm-socket
          mountPath: /var/run/aesmd/aesm.socket
        - name: client-cm-vol
          mountPath: /root/.kube/config
          subPath: kubeconfig_conf
          readOnly: true
        - name: client-cm-vol
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl_conf
          readOnly: true
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/logs
          subPath: shared_logs_dir
        #- mountPath: /dev/sgx_enclave
        #  name: dev-enclave
        #- mountPath: /dev/sgx_provision
        #  name: dev-provision
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/work/kms_data
          subPath: kms_data
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/work/kms_key
          subPath: kms_key
        #- name: $clientAuthPasswordSecretName
        #  mountPath: /ppml/trusted-big-data-ml/work/password
        #  readOnly: true
        #- name: $clientSslKeysSecretName
        #  mountPath: /ppml/trusted-big-data-ml/work/keys
        #  readOnly: true
        - name: $clientSharedVolName
          mountPath: $workloadOutputPath
          #subPathExpr: executor-\\\$(POD_NAME)
          subPath: simplequery
        #resources:
          #requests:
            #cpu: 16
            #memory: 128Gi
            #sgx.intel.com/epc: 133258905600
            #sgx.intel.com/enclave: 10
            #sgx.intel.com/provision: 10
          #limits:
            #cpu: 16
            #memory: 128Gi
            #sgx.intel.com/epc: 133258905600
            #sgx.intel.com/enclave: 10
            #sgx.intel.com/provision: 10
    EOF


    exec 2>&7 7>&-
    exec 1>&6 6>&-


    # disalbe echo commands to the terminal output
    set +ex
    # prepare env_vars
    ENV_VARS_FILE="/ppml/trusted-big-data-ml/env-vars"
    cat > \${ENV_VARS_FILE} << EOF
    POLICY_ID="\${POLICY_ID}"
    CLIENT_SPARK_AUTH_PASS=\\\$(openssl rsautl -inkey /ppml/trusted-big-data-ml/work/password/key.txt -decrypt </ppml/trusted-big-data-ml/work/password/output.bin)
    JARS_BIGDL_HOME_LOCAL=\\\$(echo -n \\\${BIGDL_HOME}/jars/* | tr ' ' ',' | sed "s,\\\${BIGDL_HOME},local://\\\${BIGDL_HOME},g")
    JARS_BIGDL_HOME_FILE=\\\$(echo -n \\\${BIGDL_HOME}/jars/* | tr ' ' ',' | sed "s,\\\${BIGDL_HOME},file://\\\${BIGDL_HOME},g")
    JARS_SPARK_HOME_LOCAL=\\\$(echo -n \\\${SPARK_HOME}/jars/* | tr ' ' ',' | sed "s,\\\${SPARK_HOME},local://\\\${SPARK_HOME},g")
    JARS_SPARK_HOME_FILE=\\\$(echo -n \\\${SPARK_HOME}/jars/* | tr ' ' ',' | sed "s,\\\${SPARK_HOME},file://\\\${SPARK_HOME},g")

    
    SGX_ENABLED="true"
    SGX_DRIVER_JVM_MEM="12g"
    SGX_EXECUTOR_JVM_MEM="12g"
    EOF
        
    sleep infinity;

  modified_entrypoint_sh: |
    #!/bin/bash
    
    # (deprecated)
    # prep additional jars
    #[[ -e \${ALAN_HOME}/jar_files.zip ]] && /usr/bin/unzip \${ALAN_HOME}/jar_files.zip -d \${ALAN_HOME}/jars/
   

    # sgx devices
    [[ ! -d /dev/sgx ]] && mkdir /dev/sgx;
    for i in /dev/sgx_*; do
      ! test -e "/dev/sgx/\${i##*_}" && ln -s "\$i" "/dev/sgx/\${i##*_}"
    done

    set -ex

    # Check whether there is a passwd entry for the container UID
    myuid=\$(id -u)
    mygid=\$(id -g)
    # turn off -e for getent because it will return error code in anonymous uid case
    set +e
    uidentry=\$(getent passwd $myuid)
    set -e

    # If there is no passwd entry for the container UID, attempt to create one
    if [ -z "$uidentry" ] ; then
        if [ -w /etc/passwd ] ; then
            echo "$myuid:x:$myuid:$mygid:anonymous uid:$SPARK_HOME:/bin/false" >> /etc/passwd
        else
            echo "Container ENTRYPOINT failed to add passwd entry for anonymous UID"
        fi
    fi

    SPARK_K8S_CMD="\$1"
    echo "###################################### \$SPARK_K8S_CMD"
    case "\$SPARK_K8S_CMD" in
        driver | driver-py | driver-r | executor)
          shift 1
          ;;
        "")
          ;;
        *)
          echo "Non-spark-on-k8s command provided, proceeding in pass-through mode..."
          exec /usr/bin/tini -s -- "\$@"
          ;;
    esac
    
    #SPARK_CLASSPATH="\$SPARK_CLASSPATH:\${SPARK_HOME}/jars/*"
    #SPARK_CLASSPATH="\${SPARK_HOME}/jars/*"
    SPARK_CLASSPATH="\${BIGDL_HOME}/jars/*:\${SPARK_HOME}/jars/*"
    env | grep SPARK_JAVA_OPT_ | sort -t_ -k4 -n | sed 's/[^=]*=\\(.*\\)/\\1/g' > /tmp/java_opts.txt
    readarray -t SPARK_EXECUTOR_JAVA_OPTS < /tmp/java_opts.txt
    
    if [ -n "\$SPARK_EXTRA_CLASSPATH" ]; then
      SPARK_CLASSPATH="\$SPARK_CLASSPATH:\$SPARK_EXTRA_CLASSPATH"
    fi
    
    if [ -n "\$PYSPARK_FILES" ]; then
        PYTHONPATH="\$PYTHONPATH:\$PYSPARK_FILES"
    fi
    
    PYSPARK_ARGS=""
    if [ -n "\$PYSPARK_APP_ARGS" ]; then
        PYSPARK_ARGS="\$PYSPARK_APP_ARGS"
    fi
    
    R_ARGS=""
    if [ -n "\$R_APP_ARGS" ]; then
        R_ARGS="\$R_APP_ARGS"
    fi


    if [ "\$PYSPARK_MAJOR_PYTHON_VERSION" == "2" ]; then
        pyv="\$(python -V 2>&1)"
        export PYTHON_VERSION="\${pyv:7}"
        export PYSPARK_PYTHON="python"
        export PYSPARK_DRIVER_PYTHON="python"
    elif [ "\$PYSPARK_MAJOR_PYTHON_VERSION" == "3" ]; then
        pyv3="\$(python3 -V 2>&1)"
        export PYTHON_VERSION="\${pyv3:7}"
        export PYSPARK_PYTHON="python3"
        export PYSPARK_DRIVER_PYTHON="python3"
    fi


    #(deprecated)
    # 20230201 alan define ATTESTAION function
    attestation() {
      # attest to ehsm Server
      ## type 1 from /ppml/trusted-big-data-ml/verify-attestation-service.sh
      JARS="\${SPARK_HOME}/jars/*:\${BIGDL_HOME}/jars/*"
      /opt/jdk8/bin/java -Xmx512m \\
        -cp "\${JARS}" \\
        com.intel.analytics.bigdl.ppml.attestation.VerificationCLI \\
        -i "\${APP_ID}" \\
        -k "\${API_KEY}" \\
        -c "\${CHALLENGE_STRING}" \\
        -u "\${ATTESTATION_URL}" \\
        -t "\${ATTESTATION_TYPE}" 2>&1 | tee -a /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_VerificationCLI_attestation.log
      ## type 2 from /opt/entrypoint.sh
      [[ ! -d /dev/attestation ]] && /usr/bin/mkdir /dev/attestation
      /opt/jdk8/bin/java -Xmx512m \\
        -cp "\${SPARK_CLASSPATH}" \\
        com.intel.analytics.bigdl.ppml.attestation.AttestationCLI \\
        -i "\${APP_ID}" \\
        -k "\${API_KEY}" \\
        -u "\${ATTESTATION_URL}" 2>&1 | tee -a /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_AttestationCLI_attestation.log
    }


    # (deprecated)
    # 20230203 alan create ATTESTATION_COMMAND
    ## prevent any word splitting from happening
    IFS=\$'\\x00' LEGACY_ATTESTATION_COMMAND=\$(
    cat << EOF
    # attest to ehsm Server
    ## type 1 from /ppml/trusted-big-data-ml/verify-attestation-service.sh
    ## (deprecated) move to client container
    #JARS="\${SPARK_HOME}/jars/*:\${BIGDL_HOME}/jars/*"
    #/opt/jdk8/bin/java -Xmx512m -cp "\\\${JARS}" com.intel.analytics.bigdl.ppml.attestation.VerificationCLI -i "\${APP_ID}" -k "\${API_KEY}" -c "\${CHALLENGE_STRING}" -u "\${ATTESTATION_URL}" -t "\${ATTESTATION_TYPE}" 2>&1 | tee -a /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_VerificationCLI_attestation.log
    ## type 2 from /opt/entrypoint.sh
    [[ ! -d /dev/attestation ]] && /usr/bin/mkdir /dev/attestation
    /opt/jdk8/bin/java -Xmx1g -cp "\${SPARK_CLASSPATH}" com.intel.analytics.bigdl.ppml.attestation.AttestationCLI -u "\${ATTESTATION_URL}" -i "\${APP_ID}" -k "\${API_KEY}" 2>&1 | tee -a /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_AttestationCLI_attestation.log
    EOF
    )
    ## restore IFS to default
    IFS=\$' \\t\\n'

  
    # 20230203 alan use the original way
    ATTESTATION_COMMAND="/opt/jdk8/bin/java -Xmx1g -cp \\"\${SPARK_CLASSPATH}\\" com.intel.analytics.bigdl.ppml.attestation.AttestationCLI -u \\"\${ATTESTATION_URL}\\" -i \\"\${ATTESTATION_ID}\\"  -k \\"\${ATTESTATION_KEY}\\" 2>&1 | tee -a /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_AttestationCLI_attestation.log"

    case "\$SPARK_K8S_CMD" in
      driver)
        CMD=(
          "\$SPARK_HOME/bin/spark-submit"
          --conf "spark.driver.bindAddress=\$SPARK_DRIVER_BIND_ADDRESS"
          --deploy-mode client
          "\$@"
        )
        echo \$SGX_ENABLED && \\
        echo \$SGX_DRIVER_MEM_SIZE && \\
        echo \$SGX_DRIVER_JVM_MEM_SIZE && \\
        echo \$SGX_EXECUTOR_MEM_SIZE && \\
        echo \$SGX_EXECUTOR_JVM_MEM_SIZE && \\
        echo \$SGX_LOG_LEVEL && \\
        echo \$SPARK_DRIVER_MEMORY && \\
        unset PYTHONHOME && \\
        unset PYTHONPATH && \\
        if [ "\$SGX_ENABLED" == "false" ]; then
            \$SPARK_HOME/bin/spark-submit --conf spark.driver.bindAddress=\$SPARK_DRIVER_BIND_ADDRESS --deploy-mode client "\$@"
        elif [ "\$SGX_ENABLED" == "true" ]; then
            # however, /opt/spark/conf/spark.properties not found
            # original
            #export driverExtraClassPath=\`cat /opt/spark/conf/spark.properties | grep -P -o "(?<=spark.driver.extraClassPath=).*"\` && \\
            # modified
            #export driverExtraClassPath=\$(cat /opt/spark/conf/spark.properties | grep -P -o "(?<=spark.driver.extraClassPath=).*") && \\
            #echo \$driverExtraClassPath && \\
            export SGX_MEM_SIZE=\$SGX_DRIVER_MEM_SIZE && \\
            # orginal
            #export sgx_command="/opt/jdk8/bin/java -Dlog4j.configurationFile=/ppml/trusted-big-data-ml/work/spark-3.1.2/conf/log4j2.xml -Xms1G -Xmx\${SGX_DRIVER_JVM_MEM_SIZE} -cp \\"\${SPARK_CLASSPATH}:\${driverExtraClassPath}\\" org.apache.spark.deploy.SparkSubmit --conf spark.driver.bindAddress=\${SPARK_DRIVER_BIND_ADDRESS} --deploy-mode client \\"\$@\\"" && \\
            # modified
            export sgx_command="/opt/jdk8/bin/java -Dlog4j.configurationFile=/ppml/trusted-big-data-ml/work/spark-3.1.2/conf/log4j2.xml -Xms1G -Xmx\${SGX_DRIVER_JVM_MEM_SIZE} -cp \\"\${SPARK_CLASSPATH}\\" org.apache.spark.deploy.SparkSubmit --conf spark.driver.bindAddress=\${SPARK_DRIVER_BIND_ADDRESS} --deploy-mode client \\"\$@\\"" && \\
            if [ "\${ATTESTATION}" = "true" ]; then
              #(deprecated)
              # 20230201 alan use function to call attestation directly
              #[[ ! -d /dev/attestation ]] && /usr/bin/mkdir /dev/attestation
              #attestation;

              #(deprecated)
              # 20220202 alan create a shell script and execute it
              #echo "#!/bin/bash" >> temp_command.sh
              ## prevent any word splitting from happening
              #IFS=\$'\\x00'
              #echo \$ATTESTATION_COMMAND >> temp_command.sh
              ## restore IFS to default
              #IFS=\$' \\t\\n'
              #/usr/bin/chmod 755 temp_command.sh;
              #echo "\${sgx_command}" >> temp_command.sh
              #sgx_command="/bin/bash temp_command.sh && rm -rf temp_command.sh"
            
              # 20220203 alan original way
              ## for testing
              echo \$ATTESTATION_COMMAND >> /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_commands
              echo \$sgx_command >> /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_commands
              ##

              echo "\${ATTESTATION_COMMAND}" > temp_commnd_file
              echo "\${sgx_command}" >> temp_commnd_file
              /usr/bin/chmod 755 temp_commnd_file;
              sgx_command="bash temp_commnd_file && rm temp_commnd_file"
            fi
            echo \$sgx_command && \\
            ./init.sh && \\
            gramine-sgx bash  1>&2
        fi
        ;;
      driver-py)
        CMD=(
          "\$SPARK_HOME/bin/spark-submit"
          --conf "spark.driver.bindAddress=\$SPARK_DRIVER_BIND_ADDRESS"
          --deploy-mode client
          "\$@" $PYSPARK_PRIMARY $PYSPARK_ARGS
        )
        ;;
        driver-r)
        CMD=(
          "\$SPARK_HOME/bin/spark-submit"
          --conf "spark.driver.bindAddress=\$SPARK_DRIVER_BIND_ADDRESS"
          --deploy-mode client
          "\$@" $R_PRIMARY $R_ARGS
        )
        ;;
        executor)
        echo \$SGX_ENABLED && \\
        echo \$SGX_DRIVER_MEM_SIZE && \\
        echo \$SGX_DRIVER_JVM_MEM_SIZE && \\
        echo \$SGX_EXECUTOR_MEM_SIZE && \\
        echo \$SGX_EXECUTOR_JVM_MEM_SIZE && \\
        echo \$SGX_LOG_LEVEL && \\
        echo \$SPARK_EXECUTOR_MEMORY && \\
        unset PYTHONHOME && \\
        unset PYTHONPATH && \\
        if [ "\$SGX_ENABLED" == "false" ]; then
          /opt/jdk8/bin/java \\
            -Xms\$SPARK_EXECUTOR_MEMORY \\
            -Xmx\$SPARK_EXECUTOR_MEMORY \\
            "\${SPARK_EXECUTOR_JAVA_OPTS[@]}" \\
            -cp "\$SPARK_CLASSPATH" \\
            org.apache.spark.executor.CoarseGrainedExecutorBackend \\
            --driver-url \$SPARK_DRIVER_URL \\
            --executor-id \$SPARK_EXECUTOR_ID \\
            --cores \$SPARK_EXECUTOR_CORES \\
            --app-id \$SPARK_APPLICATION_ID \\
            --hostname \$SPARK_EXECUTOR_POD_IP \\
            --resourceProfileId \$SPARK_RESOURCE_PROFILE_ID
        elif [ "\$SGX_ENABLED" == "true" ]; then
          export SGX_MEM_SIZE=\$SGX_EXECUTOR_MEM_SIZE && \\
          export sgx_command="/opt/jdk8/bin/java -Dlog4j.configurationFile=/ppml/trusted-big-data-ml/work/spark-3.1.2/conf/log4j2.xml -Xms1G -Xmx\${SGX_EXECUTOR_JVM_MEM_SIZE} \${SPARK_EXECUTOR_JAVA_OPTS[@]} -cp \\"\${SPARK_CLASSPATH}\\" org.apache.spark.executor.CoarseGrainedExecutorBackend --driver-url \\"\${SPARK_DRIVER_URL}\\" --executor-id \\"\${SPARK_EXECUTOR_ID}\\" --cores \${SPARK_EXECUTOR_CORES} --app-id \\"\${SPARK_APPLICATION_ID}\\" --hostname \\"\${SPARK_EXECUTOR_POD_IP}\\" --resourceProfileId \\"\${SPARK_RESOURCE_PROFILE_ID}\\"" && \\
          if [ "\${ATTESTATION}" = "true" ]; then
            #(deprecated)
            # 20230201 alan use function to call attestation directly
            #[[ ! -d /dev/attestation ]] && /usr/bin/mkdir /dev/attestation
            #attestation;

            #(deprecated)
            # 20220202 alan create a shell script and execute it
            #echo "#!/bin/bash" >> temp_command.sh
            ## prevent any word splitting from happening
            #IFS=\$'\\x00'
            #echo \$ATTESTATION_COMMAND >> temp_command.sh
            ## restore IFS to default
            #IFS=\$' \\t\\n'
            #/usr/bin/chmod 755 temp_command.sh;
            #echo "\${sgx_command}" >> temp_command.sh
            #sgx_command="/bin/bash temp_command.sh && rm -rf temp_command.sh"
            
            # 20220203 alan original way
            ## for testing
            echo \$ATTESTATION_COMMAND >> /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_commands
            echo \$sgx_command >> /ppml/trusted-big-data-ml/logs/\${HOSTNAME}_commands
            ##

            echo "\${ATTESTATION_COMMAND}" > temp_commnd_file
            echo "\${sgx_command}" >> temp_commnd_file
            /usr/bin/chmod 755 temp_commnd_file;
            sgx_command="bash temp_commnd_file && rm temp_commnd_file"
          fi
          echo \$sgx_command && \\
          ./init.sh && \\
          gramine-sgx bash  1>&2
        fi
        ;;
    
      *)
        echo "Unknown command: \$SPARK_K8S_CMD" 1>&2
        exit 1
    esac
    
    # Execute the container CMD under tini for better hygiene
    #exec /usr/bin/tini -s -- "\${CMD[@]}"
end_of_manifest
kubectl apply -f - <&7

# create client side ssl keys secret
kubectl apply -f ${script_dir}/keys/keys.yaml
# create client side ssl password secret
kubectl apply -f ${script_dir}/password/password.yaml
# create client side ssl password secret from literal
# this is for authentication of spark jobs
kubectl create secret generic \
    ${clientLiteralAuthPasswordSecretName} \
    --from-literal secret=${clientAuthPassword} \
    --namespace $clientNamespace

# client job: kms-utils pod as a job to create sample encrypted file 
cat << end_of_manifest 1>&6
apiVersion: batch/v1
kind: Job
metadata:
  name: $clientAppJobName
  namespace: $clientNamespace
spec:
  backoffLimit: 6
  completions: 1
  completionMode: "NonIndexed"
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$clientNodeName"
      restartPolicy: Never
      volumes:
      - name: client-cm-vol
        configMap:
          name: $clientConfigMapName
          defaultMode: 0755
      - name: dev-enclave
        hostPath:
          path: /dev/sgx_enclave
      - name: dev-provision
        hostPath:
          path: /dev/sgx_provision
      - name: $clientSharedVolName
        persistentVolumeClaim:
          claimName: $clientPvcName
      containers:
      - name: $clientAppJobName
        image: $clientKmsUtilsImageName
        command: ['/bin/bash']
        args: ['/home/prep_on_kms_utils.sh']
        securityContext:
          privileged: true
        volumeMounts:
        - name: client-cm-vol
          mountPath: /home/prep_on_kms_utils.sh
          subPath: prep_on_kms_utils_sh
        - name: client-cm-vol
          mountPath: /home/generate_people_csv.py
          subPath: generate_people_csv_py
        - name: client-cm-vol
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl_conf
          readOnly: true
        - mountPath: /dev/sgx_enclave
          name: dev-enclave
        - mountPath: /dev/sgx_provision
          name: dev-provision
        - name: $clientSharedVolName
          mountPath: /home/data
          subPath: kms_data
        - name: $clientSharedVolName
          mountPath: /home/key
          subPath: kms_key
        - name: $clientSharedVolName
          mountPath: /home/logs
          subPath: shared_logs_dir
        env:
        - name: PCCS_URL
          value: "https://$pccsIP:$pccsPort/sgx/certification/v3/"
        - name: EHSM_KMS_IP
          value: "$ehsmKmsSvcIP"
        - name: EHSM_KMS_PORT
          value: "$ehsmKmsPort"
        - name: KMS_TYPE
          value: "$clientKmsDefaultType"
        - name: EHSM_ENROLL_APIKEY
          value: "$ehsmApiKey"
        - name: EHSM_ENROLL_APPID
          value: "$ehsmAppId"
end_of_manifest
kubectl apply -f - <&7


# client pod: client app container
cat << end_of_manifest 1>&6
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $clientAppDplName
  namespace: $clientNamespace
spec:
  replicas: 1
  selector:
    matchLabels:
      name: $clientAppCommonName
  template:
    metadata:
      labels:
        name: $clientAppCommonName
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$clientNodeName"
      volumes:
      - name: $clientSslKeysSecretName
        secret:
          secretName: $clientSslKeysSecretName
      - name: $clientAuthPasswordSecretName
        secret:
          secretName: $clientAuthPasswordSecretName
      - name: client-cm-vol
        configMap:
          name: $clientConfigMapName
          defaultMode: 0755
      - name: dev-aesmd
        hostPath:
          path: /var/run/aesmd
      - name: dev-enclave
        hostPath:
          path: /dev/sgx_enclave
      - name: dev-provision
        hostPath:
          path: /dev/sgx_provision
      - name: $clientSharedVolName
        persistentVolumeClaim:
          claimName: $clientPvcName
      containers:
      - name: $clientAppCommonName
        image: $clientAppImageName
        securityContext:
          privileged: true
        command: ['/bin/bash']
        args: ['/opt/client_env_prep.sh']
        volumeMounts:
        - name: client-cm-vol
          mountPath: /opt/client_env_prep.sh
          subPath: client_env_prep.sh
        - name: client-cm-vol
          mountPath: /opt/modified_entrypoint.sh
          subPath: modified_entrypoint_sh
        - name: client-cm-vol
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl_conf
          readOnly: true
        - name: client-cm-vol
          mountPath: /root/.kube/config
          subPath: client_kubeconfig
          readOnly: true
        - mountPath: /dev/sgx_enclave
          name: dev-enclave
        - mountPath: /dev/sgx_provision
          name: dev-provision
        - name: dev-aesmd
          mountPath: /var/run/aesmd
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/work/kms_data
          subPath: kms_data
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/work/kms_key
          subPath: kms_key
        - name: $clientAuthPasswordSecretName
          mountPath: /ppml/trusted-big-data-ml/work/password
          readOnly: true
        - name: $clientSslKeysSecretName
          mountPath: /ppml/trusted-big-data-ml/work/keys
          readOnly: true
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/logs
          subPath: shared_logs_dir
        - name: $clientSharedVolName
          mountPath: $workloadOutputPath
          subPath: simplequery
        - name: $clientSharedVolName
          mountPath: /ppml/trusted-big-data-ml/omniscient
          readOnly: true
        env:
        - name: RUNTIME_SPARK_MASTER
          value: "k8s://https://10.96.0.1:443"
        - name: CLIENT_K8S_NAMESPACE
          value: "$clientNamespace"
        - name: CLIENT_SPARK_DRIVER_IMAGE
          value: "$clientAppImageName"
        - name: CLIENT_SPARK_EXECUTOR_IMAGE
          value: "$clientAppImageName"
        - name: CLIENT_SPARK_DRIVER_PORT
          value: "$clientAppPort"
        - name: CLIENT_SPARK_DRIVER_HOST
          value: "$clientAppSvcName.$clientNamespace.svc.cluster.local"
        - name: CLIENT_SPARK_AUTH_PASS_SECRET_NAME
          value: "$clientAuthPasswordSecretName"
        - name: CLIENT_SPARK_LITERAL_AUTH_PASS_SECRET_NAME
          value: "$clientLiteralAuthPasswordSecretName"
        - name: CLIENT_SPARK_SSL_SRC_KEYSTORE_PASS
          value: "$clientSslSrcKeystorePassword"
        - name: CLIENT_SPARK_SSL_DEST_KEYSTORE_PASS
          value: "$clientSslDestKeystorePassword"
        - name: SIMEPLEQUERY_OUTPUT_PATH
          value: "$workloadOutputPath"
        - name: PCCS_URL
          value: "https://$pccsIP:$pccsPort/sgx/certification/v3/"
        - name: ATTESTATION
          value: "$enableAttestation"
        - name: ATTESTATION_URL
          value: "$ehsmKmsSvcIP:$ehsmKmsPort"
        - name: ATTESTATION_TYPE
          value: "EHSMAttestationService"
        - name: KMS_TYPE
          value: "EHSMKeyManagementService"
        - name: KMS_SERVER_IP
          value: "$ehsmKmsSvcIP"
        - name: KMS_SERVER_PORT
          value: "$ehsmKmsPort"
        - name: APP_ID
          value: "$ehsmAppId"
        - name: API_KEY
          value: "$ehsmApiKey"
        - name: CHALLENGE_STRING
          value: "$clientEhsmAttestChallengeString"
        ports:
        - name: driver-client
          containerPort: $clientAppPort
end_of_manifest
kubectl apply -f - <&7

# headless service for running spark in client mode
# which will be exposed to executors
cat << end_of_manifest 1>&6
---
apiVersion: v1
kind: Service
metadata:
  name: $clientAppSvcName
  namespace: $clientNamespace
spec:
  clusterIP: None
  ports:
  - name: driver-client
    port: $clientAppPort
    targetPort: $clientAppPort
  selector:
    name: $clientAppCommonName
end_of_manifest
kubectl apply -f - <&7


exec 6>&-
exec 7<&-


