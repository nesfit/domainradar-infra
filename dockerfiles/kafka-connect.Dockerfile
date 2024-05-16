FROM domrad/kafka-connect:latest

ARG MONGO_CONNECTOR_URL=https://search.maven.org/remotecontent?filepath=org/mongodb/kafka/mongo-kafka-connect/1.11.2/mongo-kafka-connect-1.11.2-all.jar

WORKDIR /opt/kafka-connect/plugins

# Copy the connectors from the context
COPY ./connect_plugins/ .

# Extract all zip files
RUN ZIP_CNT=`ls -1 *.zip 2>/dev/null | wc -l` && \
    echo "Found $ZIP_CNT zip file(s)" && \
    if [ $ZIP_CNT != 0 ]; then \
    mkdir tmp && \
    unzip '*.zip' -d tmp >/dev/null && \
    rm *.zip && \
    mv tmp/* . && \
    rmdir tmp; fi

# Download the Mongo connector
RUN wget -nv -O mongo-connect.jar ${MONGO_CONNECTOR_URL}

WORKDIR /opt/kafka-connect
