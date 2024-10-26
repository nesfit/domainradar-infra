#!/bin/bash

# Usage: ./get_collectors.sh [all]
# Returns space-separated names of Compose services that represent the collectors.

: "${COMPOSE_CMD:=docker compose}"
: "${COMPOSE_FILE:=compose.yml}"

COMPOSE_FILE_ARG="-f $COMPOSE_FILE"

SERVICES=$($COMPOSE_CMD $COMPOSE_FILE_ARG config --services)
SERVICES="$(echo $SERVICES | awk '{for(i=1;i<=NF;i++) if($i ~ /^collector/) printf("%s ", $i)}' | xargs)"

echo "$SERVICES" | xargs
