FROM eclipse-temurin:21-jre

WORKDIR /pipeline-all-in-one
COPY ./ ./

ENTRYPOINT [ "bash", "./generate_secrets.sh" ]
