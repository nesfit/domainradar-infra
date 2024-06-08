#!/bin/bash

BOOTSTRAP=${BOOTSTRAP:-kafka1:9092}
KAFKA_BIN_DIR=${KAFKA_BIN_DIR:-/opt/kafka/bin}
COMMAND_CONFIG_FILE=${COMMAND_CONFIG_FILE:-client.properties}
TOPICS_SCRIPT="$KAFKA_BIN_DIR/kafka-topics.sh"
CONFIGS_SCRIPT="$KAFKA_BIN_DIR/kafka-configs.sh"
VERBOSE_TOPICS_AFTER=${VERBOSE_TOPICS_AFTER:-0}
UPDATE_EXISTING_TOPICS=${UPDATE_EXISTING_TOPICS:-0}

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

get_configs() {
  local topic=$1
  local config

  if [[ $topic == to_process_* ]] || [[ $topic == processed_* ]] || \
       [[ $topic == "collected_IP_data" ]] || [[ $topic == "filtered_input_domains" ]]; then
    config="cleanup.policy=delete"
  elif [[ $topic == "connect_errors" ]] || [[ $topic == "feature_vectors" ]]; then
    # 7 days
    config="cleanup.policy=delete,retention.ms=604800000"
  else
    config="cleanup.policy=compact"
  fi

  if [ "$2" = "add" ]; then
    echo --config ${config//,/ --config }
  else
    echo --add-config "$config"
  fi
}

TOPICS=(to_process_zone to_process_DNS to_process_TLS to_process_RDAP_DN to_process_IP \
  processed_zone processed_DNS processed_TLS processed_RDAP_DN collected_IP_data \
  all_collected_data feature_vectors classification_results connect_errors filtered_input_domains)
PARTITIONS=(4 4 4 4 4 4 4 4 4 4 4 4 1 1 1)

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
          --replication-factor 1 --partitions "$partitions" --topic "$topic" $(get_configs "$topic" add)
    elif [[ $UPDATE_EXISTING_TOPICS -eq 1 ]]; then
        echo "Updating topic: $topic."
        $CONFIGS_SCRIPT --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" \
          --entity-type topics --entity-name "$topic" --alter $(get_configs "$topic")
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