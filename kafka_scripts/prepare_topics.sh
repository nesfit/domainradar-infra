#!/bin/bash

BOOTSTRAP=${BOOTSTRAP:-kafka1:9092}
KAFKA_BIN_DIR=${KAFKA_BIN_DIR:-/opt/kafka/bin}
COMMAND_CONFIG_FILE=${COMMAND_CONFIG_FILE:-client.properties}
TOPICS_SCRIPT="$KAFKA_BIN_DIR/kafka-topics.sh"
VERBOSE_TOPICS_AFTER=${VERBOSE_TOPICS_AFTER:-0}

touch "$COMMAND_CONFIG_FILE"
# List existing topics and store them in a variable
EXISTING_TOPICS=$($TOPICS_SCRIPT --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" --list)

topic_exists() {
    local topic=$1
    if echo "$EXISTING_TOPICS" | grep -q "^$topic$"; then
        return 0 # 0 = true in shell script
    else
        return 1 # 1 = false in shell script
    fi
}

TOPICS=(to_process_zone to_process_DNS to_process_RDAP_DN to_process_IP processed_zone processed_DNS processed_RDAP_DN collected_IP_data merged_DNS_IP all_collected_data feature_vectors classification_results)
PARTITIONS=(4 4 4 4 4 4 4 4 4 4 4 1)

SKIP_AFTER="yes"

echo Current topics:
echo "$EXISTING_TOPICS"
echo "-------"

for i in "${!TOPICS[@]}"; do
    topic="${TOPICS[$i]}"
    partitions="${PARTITIONS[$i]}"

    if ! topic_exists "$topic"; then
        SKIP_AFTER="no"
        echo "Creating topic: $topic ($partitions partitions)."
        $TOPICS_SCRIPT --create --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" \
          --replication-factor 1 --partitions "$partitions" --topic "$topic"
    fi
done

if [[ "$SKIP_AFTER" = "yes" ]]; then
  echo "No new topics were created."
  exit 0
fi

echo "-------"

echo Topics after:
if [[ $VERBOSE_TOPICS_AFTER -eq 1 ]]; then
  $TOPICS_SCRIPT --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" --list | xargs \
    -L1 $TOPICS_SCRIPT --command-config "$COMMAND_CONFIG_FILE" --bootstrap-server "$BOOTSTRAP" \
    --describe --topic
else
  $TOPICS_SCRIPT --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" --list
fi