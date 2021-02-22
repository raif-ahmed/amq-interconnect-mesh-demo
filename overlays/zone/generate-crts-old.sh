AMQ_BROKER_ROUTE_URL=zone-broker-amqps-0-svc-rte-broker-with-interconnect-mesh.apps.cluster-107d.gcp.testdrive.openshift.com
AMQ_BROKER_SVC_URL=zone-broker-amqps-0-svc
AMQ_INTERCONNECT_SVC_URL=amq-interconnect.broker-with-interconnect-mesh.svc.cluster.local
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
openssl req -new -batch -subj "/CN=${AMQ_INTERCONNECT_SVC_URL}" -key crt/internal-certs/tls.key -out crt/internal-certs/server-csr.pem

# Sign the certificate using the CA.
openssl x509 -req -in crt/internal-certs/server-csr.pem -CA crt/internal-certs/ca.crt -CAkey crt/internal-certs/ca-key.pem -out crt/internal-certs/tls.crt -CAcreateserial

# oc create secret generic inter-router-certs-secret --from-file=tls.crt=internal-certs/tls.crt  --from-file=tls.key=internal-certs/tls.key  --from-file=ca.crt=internal-certs/ca.crt

# ------- SSL/TLS to authenticate client connections (as opposed to authenticating clients using SASL) -------

# Create a new directory for the client certificates.
rm -rf crt/client-certs
mkdir crt/client-certs

# Create a private key for the CA.
openssl genrsa -out crt/client-certs/ca-key.pem 2048

# Create a certificate signing request for the CA.
openssl req -new -batch -key crt/client-certs/ca-key.pem -out crt/client-certs/ca-csr.pem

# Self sign the certificate.
openssl x509 -req -in crt/client-certs/ca-csr.pem -signkey crt/client-certs/ca-key.pem -out crt/client-certs/ca.crt

# Create a private key.
openssl genrsa -out crt/client-certs/tls.key 2048

# Create a certificate signing request for the client connections
openssl req -new -batch -subj "/CN=client" -key crt/client-certs/tls.key -out crt/client-certs/client-csr.pem

# Sign the certificate using the Client CA.
# This will be used by clients connecting to the router
openssl x509 -req -in crt/client-certs/client-csr.pem -CA crt/client-certs/ca.crt -CAkey crt/client-certs/ca-key.pem -out crt/client-certs/tls.crt -CAcreateserial

# Sign the cert using inter-router CA (In case we want to unify the CA)
# This will be used by clients connecting to the router
# openssl x509 -req -in crt/client-certs/client-csr.pem -CA crt/internal-certs/ca.crt -CAkey crt/internal-certs/ca-key.pem -out crt/client-certs/client-cert.pem -CAcreateserial

#oc create secret generic client-ca-secret --from-file=ca.crt=client-certs/ca.crt --from-file=tls.crt=client-certs/ca.crt --from-file=tls.key=client-certs/ca-key.pem


# ------- Java keystores - this will be used by the external Java AMQP test client -------

rm -rf crt/broker-certs
mkdir crt/broker-certs

# Import the root CA cert into client truststore
keytool -storetype jks -keystore crt/broker-certs/broker-jks.truststore -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -keypass $AMQ_CLIENT_KEYSTORE_PASSWORD -importcert -alias ca -file crt/client-certs/ca.crt -noprompt
keytool -import -alias service_tls -keystore crt/broker-certs/broker-jks.truststore -file crt/client-certs/tls.crt -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -keypass $AMQ_CLIENT_KEYSTORE_PASSWORD -noprompt

# Generate certs for AMQ brokers and insert into a truststore (for Java client apps)
keytool -genkey -alias broker -keyalg RSA -keystore crt/broker-certs/broker.ks -keypass $AMQ_BROKER_KEYSTORE_PASSWORD -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -dname "CN=${AMQ_BROKER_SVC_URL}, ou=Consulting, o=RH Demo, c=NL" -ext "SAN=dns:${AMQ_BROKER_ROUTE_URL}" -storetype pkcs12
keytool -export -alias broker -keystore crt/broker-certs/broker.ks -file crt/broker-certs/broker-cert -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -keypass $AMQ_BROKER_KEYSTORE_PASSWORD
keytool -import -alias broker -keystore crt/broker-certs/broker-jks.truststore -file crt/broker-certs/broker-cert -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -keypass $AMQ_CLIENT_KEYSTORE_PASSWORD -noprompt

keytool -importkeystore -srckeystore crt/broker-certs/broker.ks -srcstorepass $AMQ_BROKER_KEYSTORE_PASSWORD -srckeypass $AMQ_BROKER_KEYSTORE_PASSWORD -srcalias broker -destalias broker -destkeystore crt/broker-certs/broker.p12 -deststoretype PKCS12 -deststorepass $AMQ_BROKER_KEYSTORE_PASSWORD -destkeypass $AMQ_BROKER_KEYSTORE_PASSWORD
openssl pkcs12 -in crt/broker-certs/broker.p12 -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD -nodes -nocerts -out crt/broker-certs/tls.key
openssl pkcs12 -in crt/broker-certs/broker.p12 -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD -clcerts -nokeys -out crt/broker-certs/tls.crt
openssl pkcs12 -in crt/broker-certs/broker.p12 -passin pass:$AMQ_BROKER_KEYSTORE_PASSWORD -cacerts -nokeys -out crt/broker-certs/ca.crt

#keytool -export -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -alias broker -keystore crt/broker-certs/broker.ks -file crt/broker-certs/ca.crt
#keytool -list -keystore crt/broker-certs/broker.ks -storepass $AMQ_BROKER_KEYSTORE_PASSWORD -rfc > crt/broker-certs/ca.crt
