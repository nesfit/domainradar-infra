#!/bin/bash

# Usage: ./service_runner.sh [cluster] [command] [additional arguments for the compose command]
# Runs a Compose command on all the pipeline services (and not on Kafka brokers and databases).
# If the "cluster" argument is provided, the command will use the cluster override Compose file.
# If no command is provided, the script will default to "logs".
# Examples:
# ./service_runner.sh logs
# ./service_runner.sh cluster logs -f
# ./service_runner.sh up -d

: "${COMPOSE_CMD:=docker compose}"
: "${COMPOSE_FILE:=compose.yml}"

if [ "$1" = "cluster" ]; then
    COMPOSE_FILE_ARG="-f $COMPOSE_FILE -f compose.cluster-override.yml"
    CLUSTER_ARG="cluster"
    shift
else
    COMPOSE_FILE_ARG="-f $COMPOSE_FILE"
fi

if [ -z "$1" ]; then
    set -- "logs"
fi

CMD=$1
shift

SERVICES=$(./get_services.sh "$CLUSTER_ARG")

$COMPOSE_CMD $COMPOSE_FILE_ARG "$CMD" "$@" $SERVICES
