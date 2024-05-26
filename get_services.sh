#!/bin/bash

# Usage: ./get_services.sh [cluster]
# Returns space-separated names of all the services except for the Kafka brokers.

: "${COMPOSE_CMD:=docker compose}"

if [ "$1" = "cluster" ]; then
    COMPOSE_FILE="-f compose.yml -f compose.cluster-override.yml"
else
    COMPOSE_FILE="-f compose.yml"
fi

SERVICES=$($COMPOSE_CMD $COMPOSE_FILE config --services)
SERVICES=${SERVICES//kafka[0-9]/}
SERVICES=${SERVICES//$'\n'/ }
echo "$SERVICES" | xargs
