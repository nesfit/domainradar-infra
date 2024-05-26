#!/bin/bash

# Usage: ./generate_secrets_docker.sh
# This script will build a docker image that runs the generate_secrets.sh script
# to generate SSL certficates.

if docker -v; then
  if docker -v | grep -q 'podman'; then
    USERNS="--userns=keep-id"
    DOCKER="podman"
  else
    USERNS=""
    DOCKER="docker"
  fi
elif podman -v; then
  USERNS="--userns=keep-id"
  DOCKER="podman"
else
  echo "Neither docker nor podman was found."
  exit 1
fi

$DOCKER build --tag domrad/generate-secrets -f dockerfiles/generate_secrets.Dockerfile \
    --build-arg "UID=$(id -u)" --build-arg "GID=$(id -g)" .
mkdir -p secrets
$DOCKER run "$USERNS" -v "$PWD/secrets:/pipeline-all-in-one/secrets" domrad/generate-secrets:latest
