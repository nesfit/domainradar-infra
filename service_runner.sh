#!/bin/bash

# Usage: ./service_runner.sh [cluster] [command] [additional arguments for the compose command]
# Runs a Compose command on all the services except for the Kafka brokers.
# If the "cluster" argument is provided, the command will use the cluster override Compose file.
# If no command is provided, the script will default to "logs".
# Examples:
# ./service_runner.sh logs
# ./service_runner.sh cluster logs -f
# ./service_runner.sh up -d

COMPOSE_CMD="docker compose"

if [ "$1" = "cluster" ]; then
    COMPOSE_FILE="-f compose.yml -f compose.cluster-override.yml"
    shift
else
    COMPOSE_FILE="-f compose.yml"
fi

if [ -z "$1" ]; then
    set -- "logs"
fi

CMD=$1
shift

SERVICES=$($COMPOSE_CMD $COMPOSE_FILE config --services)
SERVICES=${SERVICES//kafka[0-9]/}

$COMPOSE_CMD $COMPOSE_FILE "$CMD" "$@" $SERVICES
