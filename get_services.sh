#!/bin/bash

# Usage: ./get_services.sh [all]
# Returns space-separated names of Compose service names except for the Kafka broker and databases.
# If the 'all' parameter is not used, only pipeline components (i.e., collectors, merger, extractor, clf unit) will be returned.

: "${COMPOSE_CMD:=docker compose}"
: "${COMPOSE_FILE:=compose.yml}"

COMPOSE_FILE_ARG="-f $COMPOSE_FILE"

SERVICES=$($COMPOSE_CMD --profile full $COMPOSE_FILE_ARG config --services)
SERVICES=${SERVICES//kafka[0-9]/}
SERVICES=${SERVICES//postgres/}
SERVICES=${SERVICES//mongo/}

if [ ! "$1" = "all" ]; then
    SERVICES="merger extractor classifier-unit $(echo $SERVICES | awk '{for(i=1;i<=NF;i++) if($i ~ /^collector/) printf("%s ", $i)}' | xargs)"
fi

echo "$SERVICES" | xargs
