FROM eclipse-temurin:21-jre

WORKDIR /pipeline-all-in-one
COPY generate_secrets.sh .
COPY openssl-ca.cnf .

ENTRYPOINT [ "bash", "./generate_secrets.sh" ]
