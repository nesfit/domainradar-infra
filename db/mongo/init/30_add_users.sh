#!/bin/bash

# Check variables by treating unset variables as an error when substituting.
set -u # 
: "$CONNECT_USER"
: "$UI_USER"
: "$MASTER_USER"
: "$CONNECT_PASSWORD_FILE"
: "$UI_PASSWORD_FILE"
: "$MASTER_PASSWORD_FILE"

# Check password files exist
if [ ! -f "$UI_PASSWORD_FILE" ] || [ ! -f "$CONNECT_PASSWORD_FILE" ] || [ ! -f "$MASTER_PASSWORD_FILE" ]; then
  echo "One of the password files does not exist"
  exit 1
fi

set -e # Exit if a command exits with a non-zero status.

MASTER_PASSWORD="$(head -n 1 "$MASTER_PASSWORD_FILE" | tr -d '\r\n')"
CONNECT_PASSWORD="$(head -n 1 "$CONNECT_PASSWORD_FILE" | tr -d '\r\n')"
UI_PASSWORD="$(head -n 1 "$UI_PASSWORD_FILE" | tr -d '\r\n')"

# TODO: Granular permissions

mongosh admin <<-EOMONGO
db.createUser(
  {
    user: "$MASTER_USER",
    pwd: "$MASTER_PASSWORD",
    roles: [
      { role: "root", db: "admin" },
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)
db.createUser(
  {
    user: "$CONNECT_USER",
    pwd: "$CONNECT_PASSWORD",
    roles: [
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)
db.createUser(
  {
    user: "$UI_USER",
    pwd: "$UI_PASSWORD",
    roles: [
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)
EOMONGO
