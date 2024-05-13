FROM domrad/kafka-connect:latest

ARG MONGO_CONNECTOR_URL=https://search.maven.org/remotecontent?filepath=org/mongodb/kafka/mongo-kafka-connect/1.11.2/mongo-kafka-connect-1.11.2-all.jar

WORKDIR /opt/kafka-connect/plugins

# Copy the connectors from the context
COPY ./connect_plugins/ .

# Extract all zip files
RUN compgen -G "*.zip" >/dev/null || exit 0 && \
    mkdir tmp && \
    unzip '*.zip' -d tmp && \
    rm *.zip && \
    mv tmp/* . && \
    rmdir tmp

# Download the Mongo connector
RUN wget -nv -O mongo-connect.jar ${MONGO_CONNECTOR_URL}

WORKDIR /opt/kafka-connect
