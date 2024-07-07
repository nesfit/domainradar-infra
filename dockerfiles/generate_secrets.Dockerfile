FROM docker.io/eclipse-temurin:21-jre
ARG UID
ARG GID

WORKDIR /pipeline-all-in-one
COPY generate_secrets.sh .
COPY misc/openssl-ca.cnf misc/openssl-ca.cnf

RUN touch /.rnd && chown ${UID}:${GID} /.rnd
USER ${UID}:${GID}
ENV RANDFILE=/.rnd

ENTRYPOINT [ "bash", "./generate_secrets.sh" ]
