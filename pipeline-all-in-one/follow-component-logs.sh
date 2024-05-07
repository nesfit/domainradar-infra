#!/bin/bash

# Usage: ./follow-component-logs.sh [COMPOSE_FILE]
# Follow the outputs of all services in a Compose file, except for the services running Kafka.
# If no Compose file is provided, it defaults to docker-compose.yml.

COMPOSE_FILE=${1:-docker-compose.yml}

SERVICES=$(docker compose -f "$COMPOSE_FILE" config --services)
SERVICES=${SERVICES//kafka[0-9]/}

docker compose -f "$COMPOSE_FILE" logs -f $SERVICES