#!/bin/bash

: "${COMPOSE_CMD:=docker compose}"

$COMPOSE_CMD -f compose.yml -f compose.cluster-override.yml "$@"
