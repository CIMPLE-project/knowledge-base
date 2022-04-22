#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

load() {
  # Load prefixes
  docker cp "${SCRIPTPATH}/prefixes.sql" "${CONTAINER_NAME}:/prefixes.sql"
  docker exec -i "${CONTAINER_NAME}" sh -c "isql-v -U dba -P \${DBA_PASSWORD} < /prefixes.sql"
}

CONTAINER_NAME="cimple-virtuoso"
load