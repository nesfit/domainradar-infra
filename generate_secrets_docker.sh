#!/bin/bash

# Usage: ./generate_secrets_docker.sh
# This script will build a docker image that runs the generate_secrets.sh script
# to generate SSL certficates.

docker build . --tag domrad/generate-secrets -f dockerfiles/generate_secrets.Dockerfile
mkdir -p secrets
chmod 770 secrets
docker run -v "$PWD/secrets:/pipeline-all-in-one/secrets" domrad/generate-secrets:latest
