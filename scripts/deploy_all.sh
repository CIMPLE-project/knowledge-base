#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
VIRTUOSO_DUMPS_PATH=${VIRTUOSO_DUMPS_PATH:-"/var/docker/cimple/virtuoso/data/dumps"}

# Load prefixes
echo "Loading prefixes..."
(cd "${SCRIPTPATH}" && ./load_prefixes.sh)

# Load commons
echo "Loading commons..."
(cd "${SCRIPTPATH}" && ./load_commons.sh)

# Load dumps
for d in "${VIRTUOSO_DUMPS_PATH}/"*/; do
  base=$(basename "${d}")
  (cd "${SCRIPTPATH}" && ./load.sh -g "http://data.cimple.eu/${base}" "${base}" "*.ttl")
done

# Load patches
echo "Loading patches..."
(cd "${SCRIPTPATH}" && ./load_patches.sh)