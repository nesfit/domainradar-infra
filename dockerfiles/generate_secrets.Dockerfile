FROM docker.io/eclipse-temurin:21-jre
ARG UID
ARG GID

WORKDIR /pipeline-all-in-one
COPY generate_secrets.sh .
COPY openssl-ca.cnf .

USER ${UID}:${GID}
ENTRYPOINT [ "bash", "./generate_secrets.sh" ]
