#!/bin/sh

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 || exit ; pwd -P )"

# Load prefixes
echo "Loading prefixes..."
(cd "${SCRIPTPATH}" && ./load_prefixes.sh)

# Load dumps
echo "Loading dumps..."
for d in "${VIRTUOSO_DATA_PATH}/dumps/graph/"*/; do
  base=$(basename "${d}")
  (cd "${SCRIPTPATH}" && ./load.sh -c -g "http://data.cimple.eu/graph/${base}" "graph/${base}" "*.*")
done

# Load ontology
echo "Loading ontology..."
(cd "${SCRIPTPATH}" && ./load.sh -c -g "http://data.cimple.eu/ontology" "ontology" "*.ttl")

# Load vocabulary
echo "Loading vocabulary..."
(cd "${SCRIPTPATH}" && ./load.sh -c -g "http://data.cimple.eu/vocabulary" "vocabulary" "*.ttl")
