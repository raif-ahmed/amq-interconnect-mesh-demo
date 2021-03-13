AMQ_INTERCONNECT_SVC_URL=*.broker-with-interconnect-mesh.svc.cluster.local
AMQ_INTERCONNECT_ROUTE_URL=DNS:amq-mesh-inter-router-broker-with-interconnect-mesh.apps.cluster-f037.gcp.testdrive.openshift.com,DNS:amq-edge-console-broker-with-interconnect-mesh.apps.cluster-f037.gcp.testdrive.openshift.com,DNS:amq-mesh-console-broker-with-interconnect-mesh.apps.cluster-f037.gcp.testdrive.openshift.com

AMQ_CLIENT_KEYSTORE_PASSWORD=passw0rd

### https://access.redhat.com/documentation/en-us/red_hat_amq/2020.q4/html/deploying_amq_interconnect_on_openshift/preparing-to-deploy-router-ocp#creating-secrets-for-tls-authentication-router-ocp

# Create a new directory for the inter-router certificates.
rm -rf crt/internal-certs
mkdir crt/internal-certs

# copy the comon ca files
cp ../../crt/ca-certs/tls.key ../../crt/ca-certs/ca.crt ../../crt/ca-certs/ca-key.pem crt/internal-certs

# Create a certificate signing request for the router.
openssl req -new -batch -subj "/CN=${AMQ_INTERCONNECT_SVC_URL}" -key crt/internal-certs/tls.key -out crt/internal-certs/server-csr.pem -addext "subjectAltName = ${AMQ_INTERCONNECT_ROUTE_URL}"

# Sign the certificate using the common CA.
openssl x509 -req -in crt/internal-certs/server-csr.pem -CA crt/internal-certs/ca.crt -CAkey crt/internal-certs/ca-key.pem -out crt/internal-certs/tls.crt -CAcreateserial

# oc create secret generic inter-router-certs-secret --from-file=tls.crt=internal-certs/tls.crt  --from-file=tls.key=internal-certs/tls.key  --from-file=ca.crt=internal-certs/ca.crt


# ------- SSL/TLS to authenticate client connections (as opposed to authenticating clients using SASL) -------

# Create a new directory for the client certificates.
rm -rf crt/client-certs
mkdir crt/client-certs

keytool -genkey -noprompt -keyalg RSA -alias client -dname "CN=${AMQ_INTERCONNECT_SVC_URL}, ou=Consulting, o=RH Demo, c=NL" -ext "SAN=${AMQ_INTERCONNECT_ROUTE_URL}" -keystore crt/client-certs/client.ks -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -keypass $AMQ_CLIENT_KEYSTORE_PASSWORD -deststoretype pkcs12


keytool -export -alias client -keystore crt/client-certs/client.ks -storepass $AMQ_CLIENT_KEYSTORE_PASSWORD -file crt/client-certs/client.der
openssl x509 -inform DER -in crt/client-certs/client.der -out crt/client-certs/tls.crt
#openssl pkcs12 -in crt/client-certs/client.ks -nocerts -nodes  -out crt/client-certs/tls.key -passin pass:$AMQ_CLIENT_KEYSTORE_PASSWORD
openssl pkcs12 -in crt/client-certs/client.ks  -nocerts -nodes -passin pass:$AMQ_CLIENT_KEYSTORE_PASSWORD | openssl rsa -out crt/client-certs/tls.key
echo $AMQ_CLIENT_KEYSTORE_PASSWORD > crt/client-certs/password.txt
