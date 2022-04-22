#!/bin/bash

# Constants
PROJECT_PATH=${PROJECT_PATH:-"/home/semantic/cimple"}
KB_PATH=${KB_PATH:-"${PROJECT_PATH}/knowledge-base"}
LOG_FILE=${LOG_FILE:-"patches.log"}
CONTAINER_NAME="cimple-virtuoso"

load() {
  # Get container ID
  containerId=$(docker ps -aqf "name=^${CONTAINER_NAME}$")
  if [[ ! "${containerId}" ]]; then
    echo "${CONTAINER_NAME}: Container not found"
    exit 1
  fi
  echo "Docker container ID: ${containerId}"

  for file in "${KB_PATH}/patches/"*; do
    # Create SQL file
    temp_file=$(mktemp)
    touch "${temp_file}"
    echo "Created temp file: ${temp_file}"

    query=$(<${file})
    echo "SPARQL ${query} ;" >> "${temp_file}"

    # Copy SQL file to container
    echo "Copying SQL file to the Docker container"
    docker cp "${temp_file}" "${containerId}:/patch.sql"

    # Execute SQL file
    echo "Executing SQL file through isql-v inside the Docker container"
    docker exec -i "${containerId}" sh -c "isql-v -U dba -P \${DBA_PASSWORD} < /patch.sql" &>> "${LOG_FILE}"
    echo "Query output saved to ${LOG_FILE}"

    # Cleanup
    echo "Removing temp file: ${temp_file}"
    rm "${temp_file}"
  done
}

load