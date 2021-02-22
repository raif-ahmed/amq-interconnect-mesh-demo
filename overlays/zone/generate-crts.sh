AMQ_BROKER_ROUTE_URL=zone-broker-amqps-0-svc-rte-broker-with-interconnect-mesh.apps.cluster-107d.gcp.testdrive.openshift.com
AMQ_BROKER_SVC_URL=zone-broker-amqps-0-svc

AMQ_INTERCONNECT_SVC_URL=*.broker-with-interconnect-mesh.svc.cluster.local
AMQ_INTERCONNECT_ROUTE_URL=DNS:amq-interconnect-edge-console-broker-with-interconnect-mesh.apps.cluster-107d.gcp.testdrive.openshift.com,DNS:amq-interconnect-mesh-console-broker-with-interconnect-mesh.apps.cluster-107d.gcp.testdrive.openshift.com

AMQ_BROKER_KEYSTORE_PASSWORD=passw0rd
AMQ_CLIENT_KEYSTORE_PASSWORD=passw0rd


### https://access.redhat.com/documentation/en-us/red_hat_amq/2020.q4/html/deploying_amq_interconnect_on_openshift/preparing-to-deploy-router-ocp#creating-secrets-for-tls-authentication-router-ocp

# Create a new directory for the inter-router certificates.
rm -rf crt/internal-certs
mkdir crt/internal-certs

# Create a private key for the CA.
openssl genrsa -out crt/internal-certs/ca-key.pem 2048

# Create a certificate signing request for the CA.
openssl req -new -sha256 -batch -key crt/internal-certs/ca-key.pem -out crt/internal-certs/ca-csr.pem -subj "/C=NL/ST=Amsterdam/L=Amsterdam/O=RH Demo/CN=RH Demo Root"

# Self sign the CA certificate.
openssl x509 -req -in crt/internal-certs/ca-csr.pem -signkey crt/internal-certs/ca-key.pem -out crt/internal-certs/ca.crt

# Create a private key.
openssl genrsa -out crt/internal-certs/tls.key 2048

# Create a certificate signing request for the router.
openssl req -new -batch -subj "/CN=${AMQ_INTERCONNECT_SVC_URL}" -key crt/internal-certs/tls.key -out crt/internal-certs/server-csr.pem -addext "subjectAltName = ${AMQ_INTERCONNECT_ROUTE_URL}"

# Sign the certificate using the CA.
openssl x509 -req -in crt/internal-certs/server-csr.pem -CA crt/internal-certs/ca.crt -CAkey crt/internal-certs/ca-key.pem -out crt/internal-certs/tls.crt -CAcreateserial

# oc create secret generic inter-router-certs-secret --from-file=tls.crt=internal-certs/tls.crt  --from-file=tls.key=internal-certs/tls.key  --from-file=ca.crt=internal-certs/ca.crt

# ------- Java keystores - this will be used by the external Java AMQP test client -------

rm -rf crt/broker-certs
mkdir crt/broker-certs

keytool -genkey -noprompt -keyalg RSA -alias broker -dname "CN=${AMQ_BROKER_SVC_URL}, ou=Consulting, o=RH Demo, c=NL" -ext "SAN=dns:${AMQ_BROKER_ROUTE_URL}" -keystore crt/broker-certs/broker.ks -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -keypass $AMQ_BROKER_KEYSTORE_PASSWORD -deststoretype pkcs12

keytool -export -alias broker -keystore crt/broker-certs/broker.ks -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -file crt/broker-certs/broker.der
openssl x509 -inform DER -in crt/broker-certs/broker.der -out crt/broker-certs/tls.crt
#openssl pkcs12 -in crt/broker-certs/broker.ks -nocerts -nodes  -out crt/broker-certs/tls.key -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD
openssl pkcs12 -in crt/broker-certs/broker.ks  -nocerts -nodes -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD | openssl rsa -out crt/broker-certs/tls.key



# ------- SSL/TLS to authenticate client connections (as opposed to authenticating clients using SASL) -------

# Create a new directory for the client certificates.
rm -rf crt/client-certs
mkdir crt/client-certs

keytool -genkey -noprompt -keyalg RSA -alias client -dname "CN=*, ou=Consulting, o=RH Demo, c=NL" -keystore crt/client-certs/client.ks -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -keypass $AMQ_CLIENT_KEYSTORE_PASSWORD -deststoretype pkcs12


keytool -export -alias client -keystore crt/client-certs/client.ks -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -file crt/client-certs/client.der
openssl x509 -inform DER -in crt/client-certs/client.der -out crt/client-certs/tls.crt
#openssl pkcs12 -in crt/client-certs/client.ks -nocerts -nodes  -out crt/client-certs/tls.key -passin pass:$AMQ_CLIENT_KEYSTORE_PASSWORD
openssl pkcs12 -in crt/client-certs/client.ks  -nocerts -nodes -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD | openssl rsa -out crt/client-certs/tls.key


# Lets trust each other

keytool -import -trustcacerts -noprompt -alias broker -keystore crt/client-certs/client.ks -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -file crt/broker-certs/broker.der
keytool -import -trustcacerts -noprompt -alias client -keystore crt/broker-certs/broker.ks -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -file crt/client-certs/client.der
