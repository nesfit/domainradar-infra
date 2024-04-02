#!/bin/bash

BOOTSTRAP=${BOOTSTRAP:-kafka1:9092}
KAFKA_BIN_DIR=${KAFKA_BIN_DIR:-/opt/kafka/bin}
COMMAND_CONFIG_FILE=${COMMAND_CONFIG_FILE:-client.properties}
TOPICS_SCRIPT="$KAFKA_BIN_DIR/kafka-topics.sh"

touch "$COMMAND_CONFIG_FILE"

echo "Waiting for Kafka to start"

until $TOPICS_SCRIPT --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" --list > /dev/null;
do
    echo "Kafka not ready"
    sleep 1
done

echo "Kafka ready"
