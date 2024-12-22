#!/bin/bash

# Usage: ./10_add_users.sh
# Adds three users to the database: for the prefilter, Kafka Connect and the ingestion controller.
# The usernames are defined by $PREFILTER_USER, $CONNECT_USER, $CONTROLLER_USER and $WEBUI_USER.
# The passwords are loaded from files defined by $PREFILTER_PASSWORD_FILE, $CONNECT_PASSWORD_FILE,
# $CONTROLLER_PASSWORD_FILE and $WEBUI_PASSWORD_FILE.
# All variables must be set in the environment before running this script.
# $POSTGRES_USER must be set to the username of the superuser.

# Check variables by treating unset variables as an error when substituting.
set -u # 
: "$PREFILTER_USER"
: "$CONNECT_USER"
: "$CONTROLLER_USER"
: "$WEBUI_USER"
: "$PREFILTER_PASSWORD_FILE"
: "$CONNECT_PASSWORD_FILE"
: "$CONTROLLER_PASSWORD_FILE"
: "$WEBUI_PASSWORD_FILE"

# Check password files exist
if [ ! -f "$PREFILTER_PASSWORD_FILE" ] || [ ! -f "$CONNECT_PASSWORD_FILE" ] || \
   [ ! -f "$CONTROLLER_PASSWORD_FILE" ] || [ ! -f "$WEBUI_PASSWORD_FILE" ]; then
  echo "One of the password files does not exist"
  exit 1
fi

set -e # Exit if a command exits with a non-zero status.
psql -v ON_ERROR_STOP=1 \
     -v PREFILTER_USER="$PREFILTER_USER" \
     -v CONNECT_USER="$CONNECT_USER" \
     -v CONTROLLER_USER="$CONTROLLER_USER" \
     -v WEBUI_USER="$WEBUI_USER" \
     -v PREFILTER_PASSWORD="$(head -n 1 "$PREFILTER_PASSWORD_FILE" | tr -d '\r\n')" \
     -v CONNECT_PASSWORD="$(head -n 1 "$CONNECT_PASSWORD_FILE" | tr -d '\r\n')" \
     -v CONTROLLER_PASSWORD="$(head -n 1 "$CONTROLLER_PASSWORD_FILE" | tr -d '\r\n')" \
     -v WEBUI_PASSWORD="$(head -n 1 "$WEBUI_PASSWORD_FILE" | tr -d '\r\n')" \
     --username "$POSTGRES_USER" <<-EOSQLA

CREATE USER :PREFILTER_USER WITH PASSWORD :'PREFILTER_PASSWORD';
CREATE USER :CONNECT_USER WITH PASSWORD :'CONNECT_PASSWORD';
CREATE USER :CONTROLLER_USER WITH PASSWORD :'CONTROLLER_PASSWORD';
CREATE USER :WEBUI_USER WITH PASSWORD :'WEBUI_PASSWORD';

EOSQLA
