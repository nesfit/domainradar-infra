#!/bin/bash

# Usage: ./generate_secrets.sh
# Generates a self-signed CA, then generates SSL keys and signs certificates for Kafka brokers and clients.
# Requires OpenSSL and Java JRE.

CA_VALIDITY_DAYS=3650
BROKER_KEY_VALIDITY_DAYS=730
CLIENT_CERT_VALIDITY_DAYS=365

CA_PASSWORD="secret_ca_password"
TRUSTSTORE_PASSWORD="secret_truststore_password"

NUM_CLIENTS=2
NUM_BROKERS=2
CLIENT_PASSWORDS=("secret_client1_password" "secret_client2_password" "secret_client3_password" "secret_client4_password" "secret_client5_password")
BROKER_PASSWORDS=("secret_broker1_password" "secret_broker2_password")

SECRETS_DIR="secrets"
CA_KEYSTORE="ca"

BROKER_IPS=("192.168.100.2,IP:192.168.103.2" "192.168.100.3,IP:192.168.103.3")

echo "Making directories"

mkdir -p "$SECRETS_DIR" "$SECRETS_DIR/$CA_KEYSTORE"
echo 01 > "$SECRETS_DIR/$CA_KEYSTORE/serial.txt"
touch "$SECRETS_DIR/$CA_KEYSTORE/index.txt"

cd "$SECRETS_DIR" || exit 1

# Generate Custom CA
echo "Creating CA..."

cd "$CA_KEYSTORE" || exit 1
openssl req -x509 -config "../../misc/openssl-ca.cnf" -newkey rsa:4096 -sha256 -nodes \
    -keyout "ca-key" -out "ca-cert" -passout "pass:$CA_PASSWORD" \
    -subj "/CN=RootCA/O=DomainRadar/L=Brno/C=CZ" -days "$CA_VALIDITY_DAYS"
cd .. || exit

# Create truststore and import CA cert
echo "Creating truststore and importing CA cert..."
keytool -keystore kafka.truststore.jks -alias CARoot -import -file ca/ca-cert \
    -storepass "$TRUSTSTORE_PASSWORD" -noprompt

# For each broker: create keystore, generate keypair, create CSR, sign CSR with CA, import both CA and signed cert into keystore
for ((i=1; i <= NUM_BROKERS; i++)); do
    echo "----------------------------"
    echo "Processing broker kafka$i..."

    keytool -keystore kafka$i.keystore.jks -alias kafka$i -validity $BROKER_KEY_VALIDITY_DAYS \
        -genkey -keyalg RSA \
        -storepass "${BROKER_PASSWORDS[$i-1]}" -keypass "${BROKER_PASSWORDS[$i-1]}" \
        -dname "CN=kafka$i, OU=Brokers, O=DomainRadar, C=CZ" \
        -ext "SAN=DNS:kafka$i,DNS:kafka$i.domrad,DNS:feta4.fit.vutbr.cz,IP:${BROKER_IPS[$i-1]},DNS:localhost,IP:127.0.0.1"

    keytool -keystore kafka$i.keystore.jks -alias kafka$i -certreq -file kafka$i.csr \
        -storepass "${BROKER_PASSWORDS[$i-1]}" -keypass "${BROKER_PASSWORDS[$i-1]}" \
        -ext "SAN=DNS:kafka$i,DNS:kafka$i.domrad,DNS:feta4.fit.vutbr.cz,IP:${BROKER_IPS[$i-1]},DNS:localhost,IP:127.0.0.1"

    cd "$CA_KEYSTORE" || exit 1
    openssl ca -batch -config ../../misc/openssl-ca.cnf -policy signing_policy -extensions signing_req \
        -days "$BROKER_KEY_VALIDITY_DAYS" -out "../kafka$i-cert-signed" -infiles "../kafka$i.csr"
    cd .. || exit

    keytool -keystore kafka$i.keystore.jks -alias CARoot -import -file "$CA_KEYSTORE/ca-cert" -storepass "${BROKER_PASSWORDS[$i-1]}" -noprompt

    keytool -keystore kafka$i.keystore.jks -alias kafka$i -import -file kafka$i-cert-signed -storepass "${BROKER_PASSWORDS[$i-1]}" -noprompt

    #rm ./*.csr
    mkdir -p "secrets_kafka$i"
    mv kafka$i* "secrets_kafka$i/"
done

# Generate client keypairs and certificates
for ((i=1; i <= NUM_CLIENTS; i++)); do
    echo "Creating client$i keystore and certificate..."

    CLIENT_PASSWORD="${CLIENT_PASSWORDS[$i-1]}"

    keytool -keystore "client$i.keystore.jks" -alias "client$i" -validity $CLIENT_CERT_VALIDITY_DAYS -genkey \
        -keyalg RSA -storepass "$CLIENT_PASSWORD" -keypass "$CLIENT_PASSWORD" \
        -dname "CN=client$i, OU=KafkaClients, O=DomainRadar, L=Brno, C=CZ"

    keytool -keystore "client$i.keystore.jks" -alias "client$i" -certreq -file "client$i.csr" -storepass "$CLIENT_PASSWORD" -keypass "$CLIENT_PASSWORD"

    cd "$CA_KEYSTORE" || exit 1
    openssl ca -batch -config ../../misc/openssl-ca.cnf -policy signing_policy -extensions signing_req \
        -days "$CLIENT_CERT_VALIDITY_DAYS" -out "../client$i-cert.pem" -infiles "../client$i.csr"
    cd .. || exit

    # Import the CA certificate
    keytool -keystore "client$i.keystore.jks" -alias CARoot -import -file "$CA_KEYSTORE/ca-cert" -storepass "$CLIENT_PASSWORD" -noprompt
    # Import the signed clientcertificate
    keytool -keystore "client$i.keystore.jks" -alias "client$i" -import -file "client$i-cert.pem" -storepass "$CLIENT_PASSWORD" -noprompt
    # Export to PKCS12 and then to PEM
    keytool -importkeystore -srckeystore "client$i.keystore.jks" -srcstorepass "$CLIENT_PASSWORD" -destkeystore "client$i.keystore.p12" -deststoretype PKCS12 -deststorepass "$CLIENT_PASSWORD"
    openssl pkcs12 -in "client$i.keystore.p12" -nocerts -out "client$i-priv-key.pem" -passin "pass:$CLIENT_PASSWORD" -passout "pass:$CLIENT_PASSWORD"
    rm "client$i.keystore.p12"

    rm ./*.csr
    mkdir -p "secrets_client$i"
    mv client$i* "secrets_client$i/"
done

OWNER="$(id -u):$(id -g)"
echo "Changing permissions (UID:GID = $OWNER, 755/644 for all dirs/files, 600 for CA files)."
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;
chmod 600 ca/*
chmod 700 ca
chown -R "$OWNER" .

echo "SSL setup for Kafka is complete."
