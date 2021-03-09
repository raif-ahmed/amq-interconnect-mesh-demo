AMQ_BROKER_ROUTE_URL=dns:edge-broker-amqps-0-svc-rte-broker-edge.apps.cluster-f037.gcp.testdrive.openshift.com
AMQ_BROKER_SVC_URL=*.broker-edge.svc.cluster.local

AMQ_BROKER_KEYSTORE_PASSWORD=passw0rd


# ------- Java keystores - this will be used by the external Java AMQP test client -------

rm -rf crt/broker-certs
mkdir crt/broker-certs

keytool -genkey -noprompt -keyalg RSA -alias broker -dname "CN=${AMQ_BROKER_SVC_URL}, ou=Consulting, o=RH Demo, c=NL" -ext "SAN=${AMQ_BROKER_ROUTE_URL}" -keystore crt/broker-certs/broker.ks -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -keypass $AMQ_BROKER_KEYSTORE_PASSWORD -deststoretype pkcs12

keytool -export -alias broker -keystore crt/broker-certs/broker.ks -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -file crt/broker-certs/broker.der
openssl x509 -inform DER -in crt/broker-certs/broker.der -out crt/broker-certs/tls.crt
#openssl pkcs12 -in crt/broker-certs/broker.ks -nocerts -nodes  -out crt/broker-certs/tls.key -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD
openssl pkcs12 -in crt/broker-certs/broker.ks  -nocerts -nodes -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD | openssl rsa -out crt/broker-certs/tls.key
