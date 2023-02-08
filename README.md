# Intel Bigdl with PPML workload

## simplequery:
The README.MD on gitlab is underconstruction. Please refer to [this page](https://hackmd.io/@3oatvhDfTSqijOwo0tingw/Syp8dnHuj) for temporary instrctions.
1. Preparation:
	- Done preparation of several SGX-enables nodes(in this case, `wn{21,22,11}.openlab`)
	- Done registration of Intel provision certificate and obtained API key
	- Deployed a kubernetes cluster
	- Configured variables in `deployment/install-bigdl-pccs.sh`
	- Configured variables in `deployment/install-bigdl-ehsm-kms-v5.sh`
2. deployment:
	``` bash
	/bin/bash deployment/install-bigdl-pccs.sh
	/bin/bash deployment/install-bigdl-ehsm-kms-v5.sh
	```
3. Sample spark submit command:
	``` bash
	# first use "kubectl exec" into client container
	source env-vars; /opt/jdk8/bin/java \
	-cp "${SPARK_HOME}/conf/:${SPARK_HOME}/jars/*" -Xmx16g org.apache.spark.deploy.SparkSubmit \
	--conf spark.driver.host="${CLIENT_SPARK_DRIVER_HOST}" \
	--conf spark.driver.port="${CLIENT_SPARK_DRIVER_PORT}" \
	--conf spark.authenticate=true \
	--conf spark.authenticate.secret="${CLIENT_SPARK_AUTH_PASS}" \
	--conf spark.kubernetes.executor.secretKeyRef.SPARK_AUTHENTICATE_SECRET="${CLIENT_SPARK_LITERAL_AUTH_PASS_SECRET_NAME}:secret" \
	--conf spark.kubernetes.driver.secretKeyRef.SPARK_AUTHENTICATE_SECRET="${CLIENT_SPARK_LITERAL_AUTH_PASS_SECRET_NAME}:secret" \
	--conf spark.network.crypto.enabled=true \
	--conf spark.kubernetes.namespace=${CLIENT_K8S_NAMESPACE} \
	--conf spark.authenticate.enableSaslEncryption=true \
	--conf spark.network.crypto.keyLength=128 \
	--conf spark.network.crypto.keyFactoryAlgorithm=PBKDF2WithHmacSHA1 \
	--conf spark.io.encryption.enabled=true \
	--conf spark.io.encryption.keySizeBits=128 \
	--conf spark.io.encryption.keygen.algorithm=HmacSHA1 \
	--conf spark.ssl.enabled=true \
	--conf spark.ssl.port=8043 \
	--conf spark.ssl.keyPassword=${CLIENT_SPARK_SSL_SRC_KEYSTORE_PASS} \
	--conf spark.ssl.keyStorePassword=${CLIENT_SPARK_SSL_DEST_KEYSTORE_PASS} \
	--conf spark.ssl.keyStore=/ppml/trusted-big-data-ml/work/keys/keystore.jks \
	--conf spark.ssl.keyStoreType=JKS \
	--conf spark.ssl.trustStore=/ppml/trusted-big-data-ml/work/keys/keystore.jks \
	--conf spark.ssl.trustStorePassword="${CLIENT_SPARK_SSL_DEST_KEYSTORE_PASS}" \
	--conf spark.ssl.trustStoreType=JKS \
	--conf spark.network.timeout=10000000 \
	--conf spark.executor.heartbeatInterval=10000000 \
	--conf spark.python.use.daemon=false \
	--conf spark.python.worker.reuse=false \
	--conf spark.cores.max=8 \
	--conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
	--conf spark.kubernetes.driver.podTemplateFile=/ppml/trusted-big-data-ml/spark-driver-template.yaml \
	--conf spark.kubernetes.executor.podTemplateFile=/ppml/trusted-big-data-ml/spark-executor-template.yaml \
	--conf spark.kubernetes.executor.deleteOnTermination=false \
	--conf spark.kubernetes.sgx.enabled=true \
	--conf spark.kubernetes.sgx.driver.jvm.mem=4g \
	--conf spark.kubernetes.sgx.executor.jvm.mem=4g \
	--conf spark.kubernetes.driver.container.image="${CLIENT_SPARK_DRIVER_IMAGE}" \
	--conf spark.kubernetes.executor.container.image="${CLIENT_SPARK_EXECUTOR_IMAGE}" \
	--conf spark.eventLog.enabled=true \
	--conf spark.eventLog.dir="${SIMEPLEQUERY_OUTPUT_PATH}" \
	--master "${RUNTIME_SPARK_MASTER}" \
	--deploy-mode client \
	--driver-memory 8g \
	--driver-cores 2 \
	--executor-memory 8g \
	--executor-cores 2 \
	--num-executors 2 \
	--name simplequery \
	--verbose \
	--class com.intel.analytics.bigdl.ppml.examples.SimpleQuerySparkExample \
	--jars "${JARS_BIGDL_HOME_LOCAL}" \
	local://${BIGDL_HOME}/jars/bigdl-ppml-spark_3.1.2-2.2.0-SNAPSHOT.jar \
	--inputEncryptModeValue "AES/CBC/PKCS5Padding" \
	--inputPath "/ppml/trusted-big-data-ml/work/kms_data/" \
	--outputEncryptModeValue "AES/CBC/PKCS5Padding" \
	--outputPath "${SIMEPLEQUERY_OUTPUT_PATH}/simplequery" \
	--primaryKeyPath "/ppml/trusted-big-data-ml/work/kms_key/ehsm_encrypted_primary_key" \
	--dataKeyPath "/ppml/trusted-big-data-ml/work/kms_key/ehsm_encrypted_data_key" \
	--kmsType "${KMS_TYPE}" \
	--kmsServerIP "${KMS_SERVER_IP}" \
	--kmsServerPort "${KMS_SERVER_PORT}" \
	--ehsmAPPID "${APP_ID}" \
	--ehsmAPIKEY "${API_KEY}"
	```
