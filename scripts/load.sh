#!/bin/bash

# Constants
PROJECT_PATH=${PROJECT_PATH:-"/home/semantic/cimple"}
KB_PATH=${KB_PATH:-"${PROJECT_PATH}/knowledge-base"}
VIRTUOSO_DUMPS_PATH=${VIRTUOSO_DUMPS_PATH:-"/var/docker/cimple/virtuoso/data/dumps"}
CONTAINER_NAME=${CONTAINER_NAME:-"cimple-virtuoso"}
LOG_FILE=${LOG_FILE:-"load.log"}

# $1 = path to directory which contains RDF files
delete_rdf() {
  find "$1" -name "*.rdf" -type f -delete
  find "$1" -name "*.rdfs" -type f -delete
  find "$1" -name "*.ttl" -type f -delete
  find "$1" -name "*.n3" -type f -delete
}

# $1 = sql query to execute into the container
execute_sql() {
  local containerId
  local query
  local temp_file

  # Get container ID
  containerId=$(docker ps -aqf "name=${CONTAINER_NAME}")
  if [[ ! "${containerId}" ]]; then
    echo "${CONTAINER_NAME}: Container not found"
    exit 1
  fi
  echo "Docker container ID: ${containerId}"

  # Get query
  query="${1}"
  echo "-----------------"
  echo -e "${query}"
  echo "-----------------"
  echo -e "${query}" &>> "${LOG_FILE}"


  # Create SQL file
  temp_file=$(mktemp)
  touch "${temp_file}"
  echo "Created temp file: ${temp_file}"
  echo -e "${1}" >> "${temp_file}"

  # Copy SQL file to container
  echo "Copying SQL file to the Docker container"
  docker cp "${temp_file}" "${containerId}:/load_dump.sql"

  # Execute SQL file
  echo "Executing SQL file through isql-v inside the Docker container"
  docker exec -i "${containerId}" sh -c "isql-v -U dba -P \${DBA_PASSWORD} < /load_dump.sql" &>> "${LOG_FILE}"
  echo "Query output saved to ${LOG_FILE}"

  # Cleanup
  echo "Removing temp file: ${temp_file}"
  rm "${temp_file}"
}

# Get arguments
PROG=`basename $0`
getopt -T > /dev/null
if [ $? -eq 4 ]; then
  # GNU enhanced getopt is available
  ARGS=`getopt --name "$PROG" --long help,parallel:,graph:,clear --options hp:g:c -- "$@"`
else
  # Original getopt is available (no long option names, no whitespace, no sorting)
  ARGS=`getopt hp:g:c "$@"`
fi
if [ $? -ne 0 ]; then
  echo "$PROG: usage error (use -h for help)" >&2
  exit 2
fi
eval set -- $ARGS

HELP=false
CLEAR=false
PARALLEL=1
GRAPH=""

while true; do
  case "$1" in
    -p | --parallel ) PARALLEL="${2}"; shift ;;
    -g | --graph ) GRAPH="${2}"; shift ;;
    -h | --help ) HELP=true ;;
    -c | --clear ) CLEAR=true; ;;
    -- ) shift; break ;;
  esac
  shift
done

if [ "$HELP" = true ] ; then
  echo "-h --help       Show help"
  echo "-p --parallel   Number of parallel threads for loading RDF data (through rdf_loader_run())"
  echo "-g --graph      Name of graph to load the data into"
  echo "-c --clear      Clear graph before loading"
  exit 1
fi

# Make sure that graph is defined if clear is set
if [ "$CLEAR" = true ] ; then
  if [ -z "${GRAPH}" ] ; then
    echo "$PROG: Graph name must not be empty when -c is set. Please enter a graph name using -g"
    exit 2
  fi
fi

query="DELETE FROM DB.DBA.load_list;\n"
if [ "$CLEAR" = true ] ; then
  query="${query} SPARQL CLEAR GRAPH <${GRAPH}>;\n"
fi
query="${query} ld_dir_all('dumps/${1:-"${2:-""}"}', '${2:-"*.*"}', '${GRAPH}');\n"
query="${query} SELECT * FROM DB.DBA.load_list;\n"
for i in $(seq 1 ${PARALLEL:-1}); do
  query="${query} rdf_loader_run();\n"
done
query="${query} cl_exec('checkpoint');\n"

# Temporarily disable transaction log to improve speed
execute_sql "log_enable(2,1);"

# Temporarily disable indexing
execute_sql "DB.DBA.VT_BATCH_UPDATE ('DB.DBA.RDF_OBJ', 'ON', NULL);"

# Execute the main query
execute_sql "${query}"

# Re-enable transaction log
execute_sql "log_enable(1,1);"

# Re-enable indexing and force re-indexing
execute_sql "DB.DBA.RDF_OBJ_FT_RULE_ADD (null, null, 'All');\nDB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ();"
