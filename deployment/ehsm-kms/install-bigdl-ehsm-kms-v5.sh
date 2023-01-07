# Attestation

# Configure the variables to be passed into the templates.
#export nfsServerIp=your_nfs_server_ip
#export nfsPath=a_nfs_shared_folder_path_on_the_server
export appNamespace="bigdl-alan-2"
export couchdbRootUsername="YWRtaW4="
export couchdbRootPassword="YWRtaW4="
export plain_couchdbRootUsername="$(echo -n ${couchdbRootUsername} | base64 -d)"
export plain_couchdbRootPassword="$(echo -n ${couchdbRootPassword} | base64 -d)"

export storageClassName="gfs-user"
export sharedVolumeClaimName="ehsm-shared-volume-claim"
export sharedVolumeName="ehsm-shared-volume"

# Set the versions according to your images
export dkeyserverImageName="docker.io/intelccc/ehsm_dkeyserver-dev:0.3.2"
export couchdbImageName="docker.io/library/couchdb:3.2"
export dkeycacheImageName="docker.io/intelccc/ehsm_dkeycache-dev:0.3.2"
export ehsmKmsImageName="docker.io/intelccc/ehsm_kms_service-dev:0.3.2"
export kmsUtilsImageName="docker.io/intelanalytics/kms-utils:0.3.0-SNAPSHOT"
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
export dkeyserverCommonName="dkeyserver"
export dkeyserverStsName="${dkeyserverCommonName}"
export dkeyserverSvcName="${dkeyserverCommonName}"
export dkeyserverPort="8888"

export couchdbCommonName="couchdb"
export couchdbStsName="${couchdbCommonName}"
export couchdbSvcName="${couchdbCommonName}"
export couchdbPort="5984"

export ehsmKmsCommonName="bigdl-ehsm-kms"
export ehsmKmsSvcName="bigdl-ehsm-kms-service"
export ehsmKmsDplName="bigdl-ehsm-kms-deployment"
export ehsmKmsPort="9000"
#export ehsmApiKey=""
#export ehsmAppId=""


export dkeycacheCommonName="dkeycache"
export dkeycacheDplName="${dkeycacheCommonName}"
export dkeycacheSvcName="${dkeycacheCommonName}"
#export dkeycachePort=""

export kmsUtilsCommonName="kms-utils"
export kmsUtilsDplName="${kmsUtilsCommonName}"
export kmsUtilsSvcName="${kmsUtilsCommonName}"
export kmsDefaultType="ehsm"
#export kmsDefaultType="azure"
#export kmsDefaultType="simple"

export ehsmAttestCommonName="ehsm-attest"
export ehsmAttestJobName="${ehsmAttestCommonName}-jobs"
export ehsmAttestAppName="${ehsmAttestCommonName}-gramine"
export ehsmAttestImageName="docker.io/intelanalytics/bigdl-ppml-trusted-big-data-ml-python-gramine-reference:2.2.0-SNAPSHOT"
export ehsmAttestNodeName="wn11.openlab"
export ehsmAttestChallengeString=$(echo -n "foo-bar" | base64)


pccsIP=$(kubectl get svc -n ${appNamespace} | grep pccs | awk '{print($3)}')
pccsPort="18081"


# label nodes:
## - sgx modules loaded
## - aesmd.service is started
kubectl label nodes $dkeyserverNodeName dkeyservernode=true


ACTION=$1
if [[ "${ACTION}" == "undo" ]]; then
  kubectl delete svc couchdb -n "${appNamespace}" --force
  kubectl delete svc bigdl-ehsm-kms-service -n "${appNamespace}" --force
  kubectl delete svc dkeyserver -n "${appNamespace}" --force
  kubectl delete cm sgx_default_qcnl_conf_cm -n "${appNamespace}" --force
  kubectl delete deployment bigdl-ehsm-kms-deployment -n "${appNamespace}" --force
  kubectl delete cm ehsm-configmap -n "${appNamespace}" --force
  kubectl delete secret ehsm-secret -n "${appNamespace}" --force
  kubectl delete deployment dkeycache -n "${appNamespace}" --force
  kubectl delete deployment kms-utils -n "${appNamespace}" --force
  kubectl delete statefulsets.apps couchdb -n "${appNamespace}" --force
  kubectl delete statefulsets.apps dkeyserver -n "${appNamespace}" --force
  kubectl delete job "${ehsmAttestJobName}" -n "${appNamespace}"
  kubectl delete job couchdb-jobs -n "${appNamespace}" --force
  kubectl get pvc -n "${appNamespace}" | awk -v ns="${appNamespace}" '{if(NR!=1){system("kubectl delete pvc "$1" -n "ns)}}'
  kubectl get pv | grep "${appNamespace}" | awk '{system("kubectl delete pv "$1)}'
  kubectl get svc -n "${appNamespace}" | grep glusterfs | awk -v ns="${appNamespace}" '{system("kubectl delete svc "$1" -n "ns)}' 
  exit 0;
fi
  

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
      storage: 8Gi
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
  prep_on_kms_utils_sh: | 
    #!/bin/bash
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
    
    echo "generating encryption keys under /home/key......" 1>>/home/startup.log 2>&1;
    # generate keys
    bash /home/entrypoint.sh generatekeys "\${EHSM_ENROLL_APPID}" "\${EHSM_ENROLL_APIKEY}" 1>>/home/startup.log 2>&1;
    echo \$'\\n' 1>>/home/startup.log;
    
    echo "creating people.csv to /home/data/people.csv with 87 lines set......" 1>>/home/startup.log 2>&1;
    # create dummy file
    /usr/bin/python3 /home/generate_people_csv.py /home/data/people.csv 87 1>>/home/startup.log 2>&1;
    echo \$'\\n' 1>>/home/startup.log;

    echo "encrypting /home/data/people.csv......" 1>>/home/startup.log 2>&1;
    # encrypt dummy file
    bash /home/entrypoint.sh encrypt "\${EHSM_ENROLL_APPID}" "\${EHSM_ENROLL_APIKEY}" /home/data/people.csv 1>>/home/startup.log 2>&1;
    echo \$'\\n' 1>>/home/startup.log;
  verify_attestation_service_sh: |
    #!/bin/bash

    /usr/bin/mount -o remount,exec /dev;
    [[ ! -d /dev/sgx ]] && mkdir /dev/sgx;
    for i in /dev/sgx_*; do
      ! test -e "/dev/sgx/\${i##*_}" && ln -s "\$i" "/dev/sgx/\${i##*_}"
    done

    set -x
    #export ATTESTATION_URL=\$ATTESTATION_URL
    #export ATTESTATION_TYPE=\$ATTESTATION_TYPE
    #export APP_ID=\$APP_ID
    #export API_KEY=\$API_KEY
    export CHALLENGE="\${CHALLENGE_STRING}"
    export SPARK_HOME=\$SPARK_HOME
    export BIGDL_PPML_JAR=\$BIGDL_HOME/jars/*
    
    if [ "\$ATTESTATION_URL" = "your_attestation_url" ]; then
        echo "[ERROR] ATTESTATION_URL is not set!"
        echo "[INFO] PPML Application Exit!"
        exit 1
    fi
    if [ "\$ATTESTATION_TYPE" = "your_attestation_service_type" ]; then
        ATTESTATION_TYPE="EHSMAttestationService"
    fi
    if [ "\$APP_ID" = "your_app_id" ]; then
        echo "[ERROR] APP_ID is not set!"
        echo "[INFO] PPML Application Exit!"
        exit 1
    fi
    if [ "\$API_KEY" = "your_api_key" ]; then
        echo "[ERROR] API_KEY is not set!"
        echo "[INFO] PPML Application Exit!"
        exit 1
    fi
    if [ "\$CHALLENGE" = "your_challenge_string" ]; then
        echo "[ERROR] CHALLENGE is not set!"
        echo "[INFO] PPML Application Exit!"
        exit 1
    fi
    if [ "\$SPARK_HOME" = "your_spark_home" ]; then
        echo "[ERROR] SPARK_HOME is not set!"
        echo "[INFO] PPML Application Exit!"
        exit 1
    fi
    if [ "\$BIGDL_PPML_JAR" = "your_bigdl_ppml_jar" ]; then
        echo "[ERROR] BIGDL_PPML_JAR is not set!"
        echo "[INFO] PPML Application Exit!"
        exit 1
    fi
    
    JARS="\$SPARK_HOME/jars/*:\$SPARK_HOME/examples/jars/*:\$BIGDL_PPML_JAR"
    
    java -cp \$JARS com.intel.analytics.bigdl.ppml.attestation.VerificationCLI -i "\${APP_ID}" -k "\${API_KEY}" -c "\${CHALLENGE}" -u "\${ATTESTATION_URL}" -t "\${ATTESTATION_TYPE}" 2>&1 | tee -a /ppml/trusted-big-data-ml/attestation-logs/attestation.log
    sleep infinity;
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
  name: couchdb-jobs
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



# kms-utils deployment
cat << end_of_manifest 1>&6
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $kmsUtilsDplName
  namespace: $appNamespace
spec:
  replicas: 1
  selector:
    matchLabels:
      name: $kmsUtilsSvcName
  template:
    metadata:
      labels:
        name: $kmsUtilsSvcName
    spec:
      nodeSelector:
        kubernetes.io/hostname: "$dkeyserverNodeName"
      volumes:
      - name: prep-on-kms-utils-sh
        configMap:
          name: ehsm-configmap
          defaultMode: 0755
      - name: generate-people-csv
        configMap:
          name: ehsm-configmap
      - name: sgx-default-qcnl-file
        configMap:
          name: ehsm-configmap
      - name: dev-enclave
        hostPath:
          path: /dev/sgx/enclave
      - name: dev-provision
        hostPath:
          path: /dev/sgx/provision
      - name: $sharedVolumeName
        persistentVolumeClaim:
          claimName: $sharedVolumeClaimName
      containers:
      - name: $kmsUtilsSvcName
        image: $kmsUtilsImageName
        lifecycle:
          postStart:
            exec:
              command:
              - '/bin/bash'
              - '/home/prep_on_kms_utils.sh'
              #- 'if [ -c "/dev/sgx/enclave" ]; then echo "/dev/sgx/enclave is ready";elif [ -c "/dev/sgx_enclave" ]; then echo "/dev/sgx/enclave not ready, try to link to /dev/sgx_enclave"; mkdir -p /dev/sgx; ln -s /dev/sgx_enclave /dev/sgx/enclave; else echo "both /dev/sgx/enclave /dev/sgx_enclave are not ready, please check the kernel and driver";fi; if [ -c "/dev/sgx/provision" ]; then echo "/dev/sgx/provision is ready";elif [ -c "/dev/sgx_provision" ]; then echo "/dev/sgx/provision not ready, try to link to /dev/sgx_provision";mkdir -p /dev/sgx;ln -s /dev/sgx_provision /dev/sgx/provision;else echo "both /dev/sgx/provision /dev/sgx_provision are not ready, please check the kernel and driver";fi; chmod 755 /home/entrypoint.sh; sleep 5;'
        # change default ENTRYPOINT and CMD of container image
        command: ['/bin/bash']
        args: ['-c','sleep infinity;']
        securityContext:
          privileged: true
        volumeMounts:
        - name: prep-on-kms-utils-sh
          mountPath: /home/prep_on_kms_utils.sh
          subPath: prep_on_kms_utils_sh
        - name: generate-people-csv
          mountPath: /home/generate_people_csv.py
          subPath: generate_people_csv_py
        - name: sgx-default-qcnl-file
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl.conf
        - mountPath: /dev/sgx/enclave
          name: dev-enclave
        - mountPath: /dev/sgx/provision
          name: dev-provision
        - name: $sharedVolumeName
          mountPath: /home/data
          subPath: kms_data
        - name: $sharedVolumeName
          mountPath: /home/key
          subPath: kms_key
        env:
        - name: PCCS_URL
          value: "https://$pccsIP:$pccsPort/sgx/certification/v3/"
        - name: EHSM_KMS_IP
          value: "$ehsmKmsSvcIP"
        - name: EHSM_KMS_PORT
          value: "$ehsmKmsPort"
        - name: KMS_TYPE
          value: "$kmsDefaultType"
        - name: EHSM_ENROLL_APIKEY
          value: "$ehsmApiKey"
        - name: EHSM_ENROLL_APPID
          value: "$ehsmAppId"
end_of_manifest
kubectl apply -f - <&7


# Attest EHSM Server
cat << end_of_manifest 1>&6
apiVersion: batch/v1
kind: Job
metadata:
  name: $ehsmAttestJobName
  namespace: $appNamespace
spec:
  backoffLimit: 6
  completions: 1
  completionMode: "NonIndexed"
  template:
    spec:
      restartPolicy: OnFailure
      nodeSelector:
        kubernetes.io/hostname: "$ehsmAttestNodeName"
      volumes:
      - name: $sharedVolumeName
        persistentVolumeClaim:
          claimName: $sharedVolumeClaimName
      - name: spark-ssl-keys-path
        hostPath:
          path: /root/alan/keys
      - name: verify-attestation-service-sh
        configMap:
          name: ehsm-configmap
          defaultMode: 0755
      - name: sgx-default-qcnl-file
        configMap:
          name: ehsm-configmap
      - name: dev-aesmd
        hostPath:
          path: /var/run/aesmd
      - name: dev-enclave
        hostPath:
          path: /dev/sgx_enclave
      containers:
      - name: $ehsmAttestAppName
        command: ['/bin/bash']
        args: ['/ppml/trusted-big-data-ml/verify-attestation-service.sh']
        image: "$ehsmAttestImageName"
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: $sharedVolumeName
          mountPath: /ppml/trusted-big-data-ml/attestation-logs
          subPath: attestation-logs
        - name: spark-ssl-keys-path
          mountPath: /ppml/trusted-big-data-ml/work/keys
        - name: verify-attestation-service-sh 
          mountPath: /ppml/trusted-big-data-ml/verify-attestation-service.sh
          subPath: verify_attestation_service_sh
        - name: sgx-default-qcnl-file
          mountPath: /etc/sgx_default_qcnl.conf
          subPath: sgx_default_qcnl.conf
        - name: dev-aesmd
          mountPath: /var/run/aesmd
        - mountPath: /dev/sgx_enclave
          name: dev-enclave
        env:
        - name: ATTESTATION_URL
          value: "$ehsmKmsSvcIP:$ehsmKmsPort"
        - name: ATTESTATION_TYPE
          value: "EHSMAttestationService"
        - name: APP_ID
          value: "$ehsmAppId"
        - name: API_KEY
          value: "$ehsmApiKey"
        - name: CHALLENGE_STRING
          value: "$ehsmAttestChallengeString"
        - name: PCCS_URL
          valueFrom:
            configMapKeyRef:
              name: ehsm-configmap
              key: pccs_url
        - name: LOCAL_IP
          value: "127.0.0.1"
end_of_manifest
kubectl apply -f - <&7
exec 6>&-
exec 7<&-


