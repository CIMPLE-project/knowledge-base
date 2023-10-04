#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
VIRTUOSO_DUMPS_PATH=${VIRTUOSO_DUMPS_PATH:-"/var/docker/cimple/virtuoso/data/dumps"}

# Load prefixes
echo "Loading prefixes..."
(cd "${SCRIPTPATH}" && ./load_prefixes.sh)

# Load dumps
for d in "${VIRTUOSO_DUMPS_PATH}/graph/"*/; do
  base=$(basename "${d}")
  (cd "${SCRIPTPATH}" && ./load.sh -c -g "http://data.cimple.eu/graph/${base}" "graph/${base}" "*.ttl")
done

# Load ontology
(cd "${SCRIPTPATH}" && ./load.sh -c -g "http://data.cimple.eu/ontology" "ontology" "*.ttl")

# Load patches
echo "Loading patches..."
(cd "${SCRIPTPATH}" && ./load_patches.sh)
