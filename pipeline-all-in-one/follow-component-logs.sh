#!/bin/bash

COMPOSE_FILE=${1:-docker-compose.yml}

SERVICES=$(docker compose -f "$COMPOSE_FILE" config --services)
SERVICES=${SERVICES//kafka[0-9]/}

docker compose -f "$COMPOSE_FILE" logs -f $SERVICES