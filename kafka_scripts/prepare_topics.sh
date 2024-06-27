#!/bin/bash

# ----- Script options -----

BOOTSTRAP=${BOOTSTRAP:-kafka1:9092}
KAFKA_BIN_DIR=${KAFKA_BIN_DIR:-/opt/kafka/bin}
COMMAND_CONFIG_FILE=${COMMAND_CONFIG_FILE:-client.properties}
TOPICS_SCRIPT="$KAFKA_BIN_DIR/kafka-topics.sh"
CONFIGS_SCRIPT="$KAFKA_BIN_DIR/kafka-configs.sh"
# When set to 1, the script will output detailed information on all existing Kafka topics
VERBOSE_TOPICS_AFTER=${VERBOSE_TOPICS_AFTER:-0}
# When set to 1, existing topics will be updated with the target configurations
UPDATE_EXISTING_TOPICS=${UPDATE_EXISTING_TOPICS:-0}
UPDATE_PARTITIONING=${UPDATE_PARTITIONING:-0}

# ----- Topic options -----

# These variables configure the number of partitions for the input topics of the data merger,
# the feature extractor and the classifier unit. The number corresponds to the maximum
# partition-level parallelism, i.e. how many instances of the respective unit can process
# data in parallel (more instances can be run, but they won't be assigned any processing tasks
# unless some of the processing units fail).
# At the same time, this controls how many processing tasks can be run in the Connect sinks.
COLLECTOR_PARALLELISM=16
MERGER_PARALLELISM=16
EXTRACTOR_PARALLELISM=4 
CLASSIFIER_PARALLELISM=4

# The array contains the names of the topics and the number of partitions for each.
# You can use the first five lines to change the maximum partition-level parallelism 
# for the collectors.
TOPICS=(to_process_zone $COLLECTOR_PARALLELISM \
        to_process_DNS  $COLLECTOR_PARALLELISM \
        to_process_TLS  $COLLECTOR_PARALLELISM \
        to_process_RDAP_DN $COLLECTOR_PARALLELISM \
        to_process_IP   $COLLECTOR_PARALLELISM \
        processed_zone  $MERGER_PARALLELISM \
        processed_DNS   $MERGER_PARALLELISM \
        processed_TLS   $MERGER_PARALLELISM \
        processed_RDAP_DN  $MERGER_PARALLELISM \
        collected_IP_data  $MERGER_PARALLELISM \
        all_collected_data $EXTRACTOR_PARALLELISM \
        feature_vectors    $CLASSIFIER_PARALLELISM \
        # These may also have more partitions to increase the scalability of the Connect sinks.
        classification_results 4 \
        filtered_input_domains 4 \
        # These must have a single partition!
        configuration_change_requests 1 \
        configuration_states   1
        connect_errors         1)

# ----- Per-topic settings -----

get_configs() {
  # invoke as: get_configs <topic_name> [add]
  # when the 'add' argument is present, the output is suitable for passing to kafka-topics.sh
  # otherwise, it is suitable for passing to kafka-configs.sh
  local topic=$1
  local config

  if [[ $topic == to_process_* ]] || \
     [[ $topic == processed_* ]] || \
     [[ $topic == "collected_IP_data" ]]; then
    # 48 hours
    config="cleanup.policy=delete,retention.ms=172800000"
    #
  elif [[ $topic == "filtered_input_domains" ]] || \
       [[ $topic == "configuration_change_requests" ]] || \
       [[ $topic == "feature_vectors" ]]; then
    # 1 hour
    config="cleanup.policy=delete,retention.ms=3600000"
    #
  elif [[ $topic == "connect_errors" ]]; then
    # 7 days
    config="cleanup.policy=delete,retention.ms=604800000"
    #
  elif [[ $topic == "configuration_states" ]]; then
    # min compaction lag: 10 min, max compaction lag: 1 hours
    config="cleanup.policy=compact,min.compaction.lag.ms=600000,max.compaction.lag.ms=3600000"
    #
  else
    # min compaction lag: 1 hour, max compaction lag: 12 hours
    config="cleanup.policy=compact,min.compaction.lag.ms=3600000,max.compaction.lag.ms=43200000"
    #
  fi

  if [ "$2" = "add" ]; then
    # When creating a topic, the configs must be passed as separate arguments
    echo --config ${config//,/ --config }
  else
    echo --add-config "$config"
  fi
}


# ----- Main script -----

# Ensure the configuration file exists
touch "$COMMAND_CONFIG_FILE"
# List existing topics and store them in a variable
EXISTING_TOPICS=$($TOPICS_SCRIPT --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" --list)

# Check if a topic exists
topic_exists() {
    local topic=$1
    if echo "$EXISTING_TOPICS" | grep -q "^$topic$"; then
        return 0 # = true
    else
        return 1 # = false
    fi
}

SKIP_AFTER="yes"

echo Current topics:
echo "$EXISTING_TOPICS"
echo "-------"

top_len=${#TOPICS[@]}
for (( i=0; i<$top_len; i=i+2 )); do
    topic="${TOPICS[$i]}";
    partitions="${TOPICS[$((i+1))]}";

    if ! topic_exists "$topic"; then
        SKIP_AFTER="no"
        echo "Creating topic: $topic ($partitions partitions)."
        $TOPICS_SCRIPT --create --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" \
          --replication-factor 1 --partitions "$partitions" --topic "$topic" $(get_configs "$topic" add)
    else
      if [[ $UPDATE_EXISTING_TOPICS -eq 1 ]]; then
          echo "Updating settings for topic: $topic."
          $CONFIGS_SCRIPT --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" \
            --entity-type topics --entity-name "$topic" --alter $(get_configs "$topic")
      fi
      if [[ $UPDATE_PARTITIONING -eq 1 ]]; then
          echo "Altering number of partitions for topic: $topic."
          $TOPICS_SCRIPT --alter --bootstrap-server "$BOOTSTRAP" --command-config "$COMMAND_CONFIG_FILE" \
            --partitions "$partitions" --topic "$topic"
      fi
    fi
done

if [[ "$SKIP_AFTER" = "yes" ]]; then
  echo "No new topics were created."

  if [[ $VERBOSE_TOPICS_AFTER -ne 1 ]]; then
    exit 0
  fi
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
