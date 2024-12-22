#!/usr/bin/env bash

GENERATED_PASSWORDS_FILE="./generated_passwords"
RANDOM_PASSWORD_LENGTH=32

declare -A config_options=( 
    # Collector options
    ["NERD_TOKEN"]=""
    # DomainRadar Web UI
    ["WEBUI_ADMIN_USERNAME"]="admin"
    ["WEBUI_ADMIN_PASSWORD"]="please-change-me"
    ["WEBUI_PUBLIC_HOSTNAME"]="localhost"
    # Kafbat UI for Apache Kafka
    ["KAFBATUI_ADMIN_USERNAME"]="admin"
    ["KAFBATUI_ADMIN_PASSWORD"]="please-change-me"
    # Misc
    ["KAFKA_PUBLIC_HOSTNAME"]="kafka1"
    ["DNS_RESOLVERS"]="\"195.113.144.194\", \"195.113.144.233\""
    ["ID_PREFIX"]="domrad"
    # Compose scaling
    ["COLLECTORS_PY_SCALE"]="5"
    ["COLLECTORS_JAVA_CPC_SCALE"]="1"
    ["EXTRACTOR_SCALE"]="2"
    ["CLASSIFIER_SCALE"]="1"
    ["FLINK_TASKMANAGER_SCALE"]="1"
)

# Passwords for private keys, keystores and database users
declare -A passwords=(
    ["PASS_CA"]=""
    ["PASS_TRUSTSTORE"]=""
    # Client certificates and keystores
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
    # Database user passwords
    ["PASS_DB_CONNECT"]=""
    ["PASS_DB_MASTER"]=""
    ["PASS_DB_PREFILTER"]=""
    ["PASS_DB_WEBUI"]=""
    ["PASS_DB_CONTROLLER"]=""
    # Web UI: cookie encryption secret
    ["WEBUI_NUXT_SECRET"]=""  
)

ask_yes_no() {
    local prompt="$1"
    local reply

    while true; do
        read -r -p "$prompt [y/N]: " reply
        case "${reply,,}" in
            y|yes) return 0 ;;
            n|no|"" ) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

generate_random_password() {
    local result=""
    # Keep appending until we have at least 32 printable characters
    while [ ${#result} -lt "$RANDOM_PASSWORD_LENGTH" ]; do
        result+=$(head -c 64 /dev/urandom | tr -dc '[:alnum:]')
    done
    # Return exactly 32 printable characters
    echo "${result:0:$RANDOM_PASSWORD_LENGTH}"
}

fill_passwords() {
    if [[ -f "$GENERATED_PASSWORDS_FILE" ]]; then
        if ask_yes_no "A passwords file already exists. Overwrite?"; then
            rm "$GENERATED_PASSWORDS_FILE"
        else
            echo "Terminating"
            exit 1
        fi
    fi

    for key in "${!passwords[@]}"; do
        if [[ -z ${passwords["$key"]} ]]; then
            passwords["$key"]="$(generate_random_password)"
        fi

        printf "$key\t${passwords[$key]}\n" >> "$GENERATED_PASSWORDS_FILE"
    done
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

            for key in "${!passwords[@]}"; do
                # Replace $$KEY$$ with the corresponding value
                sed -i "s|\$\$${key}\$\$|${passwords[$key]}|g" "$file"
            done
        fi
    done < <(find "$dir" -type f -print0)
}

fill_passwords
replace_placeholders "."