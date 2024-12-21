#!/usr/bin/env bash

declare -A config_options=( 
    ["NERD_TOKEN"]=""
    ["WEBUI_ADMIN_USERNAME"]=""
    ["WEBUI_ADMIN_PASSWORD"]=""
    ["WEBUI_PUBLIC_HOSTNAME"]="localhost"
    ["KAFKA_PUBLIC_HOSTNAME"]="kafka1",
    ["DNS_RESOLVERS"]="\"195.113.144.194\", \"195.113.144.233\""
)

declare -A passwords=( 
    ["PASS_CA"]=""
    ["PASS_TRUSTSTORE"]=""
    ["PASS_KEY_CLASSIFIER_UNIT"]=""
    ["PASS_KEY_CONFIG_MANAGER"]=""
    ["PASS_KEY_COLLECTOR"]=""
    ["PASS_KEY_EXTRACTOR"]=""
    ["PASS_KEY_KAFKA_CONNECT"]=""
    ["PASS_KEY_INITIALIZER"]=""
    ["PASS_KEY_KAFKA_UI"]=""
    ["PASS_KEY_MERGER"]=""
    ["PASS_KEY_ADMIN"]=""
    ["PASS_KEY_BROKER_1"]=""
    ["PASS_KEY_BROKER_2"]=""
    ["PASS_KEY_BROKER_3"]=""
    ["PASS_KEY_BROKER_4"]=""
    ["PASS_KEY_BROKER_5"]=""
    ["PASS_DB_CONNECT"]=""
    ["PASS_DB_MASTER"]=""
    ["PASS_DB_PREFILTER"]=""
    ["PASS_DB_WEBUI"]=""
    ["WEBUI_NUXT_SECRET"]=""
    [""]=""
    [""]=""
)

declare -A env=(
    ["COLLECTORS_PY_SCALE"]="5"
    ["COLLECTORS_JAVA_CPC_SCALE"]="1"
    ["EXTRACTOR_SCALE"]="2"
    ["CLASSIFIER_SCALE"]="1"
    ["FLINK_TASKMANAGER_SCALE"]="1"
    ["ID_PREFIX"]="domrad"
    ["BOOTSTRAP_SERVERS"]="kafka1:9093"
)

for sound in "${!animals[@]}";
do 
    echo "$sound - ${animals[$sound]}"
done