#!/bin/bash

# Usage: ./20_add_db.sh
# Adds and initializes the database named $DOMRAD_DB_NAME.
# The usernames are defined by $PREFILTER_USER and $CONNECT_USER.

# Check variables by treating unset variables as an error when substituting.
set -u # 
: "$PREFILTER_USER"
: "$CONNECT_USER"
: "$INGESTION_USER"
: "$WEBUI_USER"
: "$DOMRAD_DB_NAME"

set -e # Exit if a command exits with a non-zero status.

# Create the database
psql -v ON_ERROR_STOP=1 \
     -v DOMRAD_DB_NAME="$DOMRAD_DB_NAME" \
     --username "$POSTGRES_USER" <<-EOSQLA
CREATE DATABASE :DOMRAD_DB_NAME;
EOSQLA

# Populate the database
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$DOMRAD_DB_NAME" -f /docker-entrypoint-initdb.d/sql/10_create_domainradar_db.sql

psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$DOMRAD_DB_NAME" -f /docker-entrypoint-initdb.d/sql/15_seed.sql

# Grant access to the users
psql -v ON_ERROR_STOP=1 \
     -v PREFILTER_USER="$PREFILTER_USER" \
     -v CONNECT_USER="$CONNECT_USER" \
     -v INGESTION_USER="$INGESTION_USER" \
     -v WEBUI_USER="$WEBUI_USER" \
     -v DOMRAD_DB_NAME="$DOMRAD_DB_NAME" \
     --username "$POSTGRES_USER" \
     --dbname "$DOMRAD_DB_NAME" -f /docker-entrypoint-initdb.d/sql/20_grant_access.sql