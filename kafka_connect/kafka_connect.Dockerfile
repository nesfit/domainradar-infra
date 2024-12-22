FROM domrad/kafka-connect:latest

WORKDIR /opt/kafka-connect/plugins

# Copy the connectors from the context
COPY ./plugins/ .

# Extract all zip files
RUN ZIP_CNT=`ls -1 *.zip 2>/dev/null | wc -l` && \
    echo "Found $ZIP_CNT zip file(s)" && \
    if [ $ZIP_CNT != 0 ]; then \
    mkdir tmp && \
    unzip '*.zip' -d tmp >/dev/null && \
    rm *.zip && \
    mv tmp/* . && \
    rmdir tmp; fi

WORKDIR /opt/kafka-connect
