#!/bin/bash

BROKER_IPS=("192.168.45.10" "192.168.45.20")

SECRETS_DIR="secrets"
BROKER_KEY_VALIDITY_DAYS=3650

CLIENT_CERT_VALIDITY_DAYS=730
NUM_CLIENTS=5
CLIENT_PASSWORDS=("secret_client1_password" "secret_client2_password" "secret_client3_password" "secret_client4_password" "secret_client5_password")

CA_KEYSTORE="ca"
CA_PASSWORD="${1:-"secret_ca_password"}"
TRUSTSTORE_PASSWORD="${2:-"secret_truststore_password"}"
BROKER_PASSWORDS=("secret_broker1_password" "secret_broker2_password")


echo "Making directories"

mkdir -p "$SECRETS_DIR" "$SECRETS_DIR/$CA_KEYSTORE"
echo 01 > "$SECRETS_DIR/$CA_KEYSTORE/serial.txt"
touch "$SECRETS_DIR/$CA_KEYSTORE/index.txt"

cd "$SECRETS_DIR" || exit

# Generate Custom CA
echo "Creating CA..."

cd "$CA_KEYSTORE" || exit
openssl req -x509 -config "../../openssl-ca.cnf" -newkey rsa:4096 -sha256 -nodes \
    -keyout "ca-key" -out "ca-cert" -passout "pass:$CA_PASSWORD"
cd .. || exit

# Create truststore and import CA cert
echo "Creating truststore and importing CA cert..."
keytool -keystore kafka.truststore.jks -alias CARoot -import -file ca/ca-cert \
    -storepass "$TRUSTSTORE_PASSWORD" -noprompt

# For each broker: create keystore, generate keypair, create CSR, sign CSR with CA, import both CA and signed cert into keystore
for i in 1 2; do
    echo "----------------------------"
    echo "Processing broker kafka$i..."
    
    keytool -keystore kafka$i.keystore.jks -alias kafka$i -validity $BROKER_KEY_VALIDITY_DAYS \
        -genkey -keyalg RSA \
        -storepass "${BROKER_PASSWORDS[$i-1]}" -keypass "${BROKER_PASSWORDS[$i-1]}" \
        -dname "CN=kafka$i, OU=Brokers, O=DomainRadar, C=CZ" \
        -ext "SAN=DNS:kafka$i,IP:${BROKER_IPS[$i-1]}"

    keytool -keystore kafka$i.keystore.jks -alias kafka$i -certreq -file kafka$i.csr \
        -storepass "${BROKER_PASSWORDS[$i-1]}" -keypass "${BROKER_PASSWORDS[$i-1]}" \
        -ext "SAN=DNS:kafka$i,IP:${BROKER_IPS[$i-1]}"

    cd "$CA_KEYSTORE" || exit
    openssl ca -batch -config ../../openssl-ca.cnf -policy signing_policy -extensions signing_req \
        -out "../kafka$i-cert-signed" -infiles "../kafka$i.csr" 
    cd .. || exit

    keytool -keystore kafka$i.keystore.jks -alias CARoot -import -file "$CA_KEYSTORE/ca-cert" -storepass "${BROKER_PASSWORDS[$i-1]}" -noprompt

    keytool -keystore kafka$i.keystore.jks -alias kafka$i -import -file kafka$i-cert-signed -storepass "${BROKER_PASSWORDS[$i-1]}" -noprompt

    #rm ./*.csr
    mkdir -p "secrets_kafka$i"
    mv kafka$i* "secrets_kafka$i/"
done

# Generate client keypairs and certificates
for i in $(seq 1 $NUM_CLIENTS); do
    echo "Creating client$i keystore and certificate..."

    CLIENT_PASSWORD="${CLIENT_PASSWORDS[$i-1]}"

    keytool -keystore "client$i.keystore.jks" -alias "client$i" -validity $CLIENT_CERT_VALIDITY_DAYS -genkey \
        -keyalg RSA -storepass "$CLIENT_PASSWORD" -keypass "$CLIENT_PASSWORD" \
        -dname "CN=client$i, OU=KafkaClient, L=Brno, C=CZ"

    keytool -keystore "client$i.keystore.jks" -alias "client$i" -certreq -file "client$i.csr" -storepass "$CLIENT_PASSWORD" -keypass "$CLIENT_PASSWORD"
    
    cd "$CA_KEYSTORE" || exit
    openssl ca -batch -config ../../openssl-ca.cnf -policy signing_policy -extensions signing_req \
        -out "../client$i-cert-signed" -infiles "../client$i.csr"
    cd .. || exit

    keytool -keystore "client$i.keystore.jks" -alias CARoot -import -file "$CA_KEYSTORE/ca-cert" -storepass "$CLIENT_PASSWORD" -noprompt

    keytool -keystore "client$i.keystore.jks" -alias "client$i" -import -file "client$i-cert-signed" -storepass "$CLIENT_PASSWORD" -noprompt

    rm ./*.csr
    mkdir -p "secrets_client$i"
    mv client$i* "secrets_client$i/"
done

echo "SSL setup for Kafka is complete."