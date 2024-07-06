#!/bin/bash

mongo_uri="$1"
aggregation_js="$2"
period_sec="$3"

shift 3

while true; do
    echo "Executing $aggregation_js"
    mongosh "$mongo_uri" --file "$aggregation_js" "$@"
    echo "Sleeping $period_sec sec"
    sleep "$period_sec"
done
