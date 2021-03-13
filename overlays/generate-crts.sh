# Create a new directory for the inter-router certificates.
rm -rf crt/ca-certs
mkdir crt/ca-certs

# Create a private key for the CA.
openssl genrsa -out crt/ca-certs/ca-key.pem 2048

# Create a certificate signing request for the CA.
openssl req -new -sha256 -batch -key crt/ca-certs/ca-key.pem -out crt/ca-certs/ca-csr.pem -subj "/C=NL/ST=Amsterdam/L=Amsterdam/O=RH Demo/CN=RH Demo Root"

# Self sign the CA certificate.
openssl x509 -req -in crt/ca-certs/ca-csr.pem -signkey crt/ca-certs/ca-key.pem -out crt/ca-certs/ca.crt

# Create a private key.
openssl genrsa -out crt/ca-certs/tls.key 2048

