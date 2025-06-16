#!/bin/bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# Cleanup function
cleanup() {
  local last_status_code=$?
  trap - SIGINT SIGTERM ERR EXIT

  # Cleanup
  echo "[REDEPLOY] Cleaning up..."
  rm -rf "/data/chunks"
  if [ -n "${TagName:-}" ]; then
    rm -rf "/data/${TagName}"
    rm "/data/${TagName}.zip"
  fi

  # Check if error occurred
  if [ $last_status_code -ne 0 ]; then
    echo "[REDEPLOY] An error occurred. Sending a failure ping to healthchecks..."
    if [ -n "${HEALTHCHECKS_PING_URL}" ]; then
      curl -fsS -m 10 --retry 5 "${HEALTHCHECKS_PING_URL}/fail"
    fi
  fi
}

# Check that "url" was passed to the script
if [ -z "${url}" ]; then
  echo "[REDEPLOY] URL not found" >&2
  exit 1
fi

# Send a start ping to healthchecks
if [ -n "${HEALTHCHECKS_PING_URL}" ]; then
  echo "[REDEPLOY] Pinging healthchecks (start)..."
  RID=$(cat /proc/sys/kernel/random/uuid)
  curl -fsS -m 10 --retry 5 "${HEALTHCHECKS_PING_URL}/start?rid=${RID}"
fi

echo "[REDEPLOY] URL: $url"

TagName=$(basename "$url")
DownloadURL=$(printf "%s" "$url" | sed "s/tag/download/")/${TagName}.zip

[ -z "${TagName}" ] && { echo "[REDEPLOY] TagName not found from URL" >&2 ; exit 1; }

# Download and extract the archive
echo "[REDEPLOY] Downloading from URL: $DownloadURL"
MaxRetries=7
RetryCount=0
while [ $RetryCount -lt $MaxRetries ]; do
  if curl -sS --fail -L -o "/data/${TagName}.zip" "$DownloadURL"; then
    echo "[REDEPLOY] Download succeeded"
    break
  else
    RetryCount=$((RetryCount + 1))
    SleepTime=$((2 ** RetryCount))
    echo "[REDEPLOY] Download failed. Attempt ${RetryCount} of ${MaxRetries}. Retrying in ${SleepTime} seconds..."
    sleep $SleepTime
  fi
done

# Check if the archive was downloaded
if [ ! -f "/data/${TagName}.zip" ]; then
  echo "[REDEPLOY] Could not download the archive!" >&2
  exit 1
fi

# Extract the archive
echo "[REDEPLOY] Extracting archive"
unzip "/data/${TagName}.zip" -d /data

# Check if the extracted directory exists
if [ ! -d "/data/${TagName}" ]; then
  echo "[REDEPLOY] Could not find the extracted directory!" >&2
  exit 1
fi

# Clone the converter scripts
if [ ! -d "/data/converter" ]; then
  echo "[REDEPLOY] Cloning converter scripts..."
  git clone https://github.com/CIMPLE-project/converter.git /data/converter
  cd /data/converter || exit
else
  echo "[REDEPLOY] Updating converter scripts..."
  cd /data/converter || exit
  git pull || true
fi

export PYTHONUNBUFFERED=1

# Install dependencies
pip install --extra-index-url https://download.pytorch.org/whl/cpu -q -r requirements.txt

# Convert to RDF/Turtle
echo "[REDEPLOY] Converting to RDF/Turtle..."
[ -d /data/cache ] || mkdir /data/cache
python -u update_KG.py --no-progress -i "/data/${TagName}" -o "/data/claimreview-kg_${TagName}.nt" -f "nt" -c "/data/cache" -g "/data/cache/claim-review.nt"

if [ ! -f "/data/claimreview-kg_${TagName}.nt" ]; then
  echo "[REDEPLOY] Could not find converted RDF file!"
  exit 1
fi

# Split into chunks
echo "[REDEPLOY] Splitting into chunks..."
[ -d /data/chunks ] || mkdir /data/chunks
python -u rdf_splitter.py -f "nt" "/data/claimreview-kg_${TagName}.nt" 50000 "/data/chunks"

# Deploy to KB
for chunkfile in /data/chunks/*.nt; do
  echo "[REDEPLOY] Deploying ${chunkfile} to KB..."
  python -u rdf_uploader.py "${chunkfile}"
done

# Create release
/scripts/create-release.sh "/data/claimreview-kg_${TagName}.nt" "${TagName}" || exit 1

# Cleanup old files and folders (older than 14 days)
echo "[REDEPLOY] Cleaning up old files and folders..."

# Remove .nt files older than 14 days from /data
echo "[REDEPLOY] Removing .nt files older than 14 days from /data..."
find /data -name "claimreview-kg_*.nt" -type f -mtime +14 -delete 2>/dev/null || true

# Remove log folders older than 14 days from /data/logs
if [ -d "/data/logs" ]; then
  echo "[REDEPLOY] Removing log folders older than 14 days from /data/logs..."
  find /data/logs -maxdepth 1 -type d -mtime +14 -exec rm -rf {} + 2>/dev/null || true
fi

echo "[REDEPLOY] Cleanup completed."

# Send a success ping to healthchecks
if [ -n "${HEALTHCHECKS_PING_URL}" ]; then
    echo "[REDEPLOY] Pinging healthchecks (success)..."
    curl -fsS -m 10 --retry 5 "${HEALTHCHECKS_PING_URL}?rid=${RID}"
fi
