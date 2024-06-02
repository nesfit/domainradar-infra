#!/bin/bash

# Usage: ./get_services.sh [cluster] [all]
# Returns space-separated names of Compose service names except for the Kafka brokers and databases.
# If the 'all' parameter is not used, only pipeline components (i.e., collectors, merger, extractor, clf unit) will be returned.

: "${COMPOSE_CMD:=docker compose}"
: "${COMPOSE_FILE:=compose.yml}"

X=0
if [ "$1" = "cluster" ]; then
    COMPOSE_FILE_ARG="-f $COMPOSE_FILE -f compose.cluster-override.yml"
    X=1
    shift 1
fi

if [ $X = 0 ]; then
    COMPOSE_FILE_ARG="-f $COMPOSE_FILE"
fi

SERVICES=$($COMPOSE_CMD $COMPOSE_FILE_ARG config --services)
SERVICES=${SERVICES//kafka[0-9]/}
SERVICES=${SERVICES//postgres/}
SERVICES=${SERVICES//mongo/}

if [ ! "$1" = "all" ]; then
    SERVICES="merger extractor classifier-unit $(echo $SERVICES | awk '{for(i=1;i<=NF;i++) if($i ~ /^collector/) printf("%s ", $i)}' | xargs)"
fi

echo "$SERVICES" | xargs
