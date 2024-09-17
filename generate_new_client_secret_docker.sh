#!/bin/bash

# Usage: ./generate_new_client_secret_docker.sh
# This script will build a docker image that runs the generate_new_client_secret.sh script
# to generate a SSL certficate for a new client.

if podman -v || (docker -v | grep -q 'podman'); then
  USERNS="--userns=keep-id"
  DOCKER="podman"
elif docker -v; then
  USERNS=""
  DOCKER="docker"
else
  echo "Neither docker nor podman was found."
  exit 1
fi

$DOCKER build --tag domrad/generate-secrets -f dockerfiles/generate_secrets.Dockerfile \
    --build-arg "UID=$(id -u)" --build-arg "GID=$(id -g)" .
mkdir -p secrets
$DOCKER run $USERNS --rm -v "$PWD/secrets:/pipeline-all-in-one/secrets" --entrypoint /bin/bash domrad/generate-secrets ./generate_new_client_secret.sh "$@"
$DOCKER image rm domrad/generate-secrets