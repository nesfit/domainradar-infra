#!/usr/bin/env bash

RANDOM_PASSWORD_LENGTH=32

declare -A config_options=( 
    ["NERD_TOKEN"]=""
    ["WEBUI_ADMIN_USERNAME"]="admin"
    ["WEBUI_ADMIN_PASSWORD"]="please-change-me"
    ["WEBUI_PUBLIC_HOSTNAME"]="localhost"
    ["KAFKA_PUBLIC_HOSTNAME"]="kafka1"
    ["DNS_RESOLVERS"]="\"195.113.144.194\", \"195.113.144.233\""
    ["ID_PREFIX"]="domrad"
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
    ["PASS_DB_CONTROLLER"]=""
    ["WEBUI_NUXT_SECRET"]=""
)

declare -A env=(
    ["COLLECTORS_PY_SCALE"]="5"
    ["COLLECTORS_JAVA_CPC_SCALE"]="1"
    ["EXTRACTOR_SCALE"]="2"
    ["CLASSIFIER_SCALE"]="1"
    ["FLINK_TASKMANAGER_SCALE"]="1"
    ["ID_PREFIX"]="${config_options[ID_PREFIX]}"
    ["BOOTSTRAP_SERVERS"]="kafka1:9093"
)

generate_random_password() {
    local result=""
    # Keep appending until we have at least 32 printable characters
    while [ ${#result} -lt "$RANDOM_PASSWORD_LENGTH" ]; do
        result+=$(head -c 64 /dev/urandom | tr -dc '[:print:]')
    done
    # Return exactly 32 printable characters
    echo "${result:0:$RANDOM_PASSWORD_LENGTH}"
}

is_valid_target() {
    local filename="$1"
    local ext="${filename##*.}"
    case "$ext" in
        sh|secret|conf|toml|xml|properties|env) return 0 ;;
        *) return 1 ;;
    esac
}

replace_placeholders() {
    local dir="$1"
    # Recursively process all files under the given directory
    while IFS= read -r -d '' file; do
        # Check if the file is a valid target for variable substitution
        if is_valid_target "$file"; then
            for key in "${!config_options[@]}"; do
                # Replace $$KEY$$ with the corresponding value
                sed -i "s|\$\$${key}\$\$|${config_options[$key]}|g" "$file"
            done
        fi
    done < <(find "$dir" -type f -print0)
}

generate_random_password