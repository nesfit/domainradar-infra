#!/bin/bash

# Usage: ./service_runner.sh <profile> [command] [additional arguments for the compose command]
# Runs a Compose command on all the pipeline services (and not on Kafka brokers and databases).
# If no command is provided, the script will default to "logs".
# Examples:
# ./service_runner.sh full logs
# ./service_runner.sh full logs -f
# ./service_runner.sh colext up -d

: "${COMPOSE_CMD:=docker compose}"
: "${COMPOSE_FILE:=compose.yml}"

COMPOSE_FILE_ARG="-f $COMPOSE_FILE"

if [ -z "$1" ]; then
    set -- "logs"
fi

CMD=$1
shift

SERVICES=$(./get_services.sh)
$COMPOSE_CMD --profile full $COMPOSE_FILE_ARG "$CMD" "$@" $SERVICES
