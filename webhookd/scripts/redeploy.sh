#!/bin/bash

echo "Url: $url"

TagName="${url##*/}"
DownloadURL="${url/tag/download}/${TagName}.zip"

[ -z "${VIRTUOSO_URL}" ] && { echo "[REDEPLOY] Missing environment variable VIRTUOSO_URL"; exit 1; }
[ -z "${TagName}" ] && { echo "[REDEPLOY] TagName not found from URL"; exit 1; }

# Download the archive
if [ ! -d "/data/${TagName}" ]; then
  echo "[REDEPLOY] Download URL: $DownloadURL"
  curl -sS -L -o "/data/${TagName}.zip" "$DownloadURL"
  unzip "/data/${TagName}.zip" -d /data
fi

# Clone the converter scripts
if [ ! -d "/data/converter" ]; then
  echo "[REDEPLOY] Cloning converter scripts..."
  git clone https://github.com/CIMPLE-project/converter.git /data/converter
  cd /data/converter
else
  echo "[REDEPLOY] Updating converter scripts..."
  cd /data/converter
  git pull
fi

# Convert to RDF/Turtle
echo "[REDEPLOY] Converting to RDF/Turtle..."
[ -d /data/cache ] || mkdir /data/cache
python -u update_KG.py -q -i "/data/${TagName}" -o "/data/claimreview-kg_${TagName}.ttl" -c "/data/cache"

# Split into chunks
echo "[REDEPLOY] Splitting into chunks..."
[ -d /data/chunks ] || mkdir /data/chunks
python -u rdf_splitter.py "/data/claimreview-kg_${TagName}.ttl" 50000 "/data/chunks"

# Deploy to KB
for chunkfile in /data/chunks/*.ttl; do
  echo "[REDEPLOY] Deploying ${chunkfile} to KB..."
  curl --digest --user "dba:${DBA_PASSWORD}" -XPOST --url "${VIRTUOSO_URL}/sparql-graph-crud-auth?graph=http://data.cimple.eu/graph/claimreview" -T "${chunkfile}"
done

# Cleanup
echo "[REDEPLOY] Cleaning up..."
rm -rf "/data/${TagName}"
rm -rf "/data/chunks"
rm "/data/${TagName}.zip"
rm "/data/claimreview-kg_${TagName}.ttl"
