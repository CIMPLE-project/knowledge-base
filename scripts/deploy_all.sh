#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Load prefixes
echo "Loading prefixes..."
(cd "${SCRIPTPATH}" && ./load_prefixes.sh)

# Load commons
echo "Loading commons..."
(cd "${SCRIPTPATH}" && ./load_commons.sh)

# Load dumps
(cd "${SCRIPTPATH}" && ./load.sh -g "http://data.cimple.eu/news" "news" "*.ttl")

# Load patches
echo "Loading patches..."
(cd "${SCRIPTPATH}" && ./load_patches.sh)