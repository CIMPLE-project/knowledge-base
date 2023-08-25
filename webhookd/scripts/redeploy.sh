#!/bin/bash

echo "Url: $url"

TagName="${url##*/}"
DownloadURL="${url/tag/download}/${TagName}.zip"

[ -z "${VIRTUOSO_URL}" ] && { echo "Missing environment variable VIRTUOSO_URL"; exit 1; }
[ -z "${TagName}" ] && { echo "TagName not found from URL"; exit 1; }

# Download the archive
if [ ! -d "/data/${TagName}" ]; then
  echo "$DownloadURL"
  curl -sS -L -o "/data/${TagName}.zip" "$DownloadURL"
  unzip "/data/${TagName}.zip" -d /data
fi

# Clone the converter scripts
if [ ! -d "./converter" ]; then
  echo "Cloning converter scripts..."
  git clone https://github.com/CIMPLE-project/converter.git converter
  cd converter/
else
  echo "Updating converter scripts..."
  cd converter/
  git pull
fi

# Convert to RDF/Turtle
echo "Converting to RDF/Turtle..."
[ -d /data/cache ] || mkdir /data/cache
python update_KG.py -q -i "/data/${TagName}" -o "/data/claimreview-kg_${TagName}.ttl" -c "/data/cache"

# Split into chunks
echo "Splitting into chunks..."
[ -d /data/chunks ] || mkdir /data/chunks
python rdf_splitter.py "/data/claimreview-kg_${TagName}.ttl" 100000 "/data/chunks"

# Deploy to KB
for chunkfile in /data/chunks/*.ttl; do
  echo "Deploying ${chunkfile} to KB..."
  curl --digest --user "dba:${DBA_PASSWORD}" -XPOST --url "${VIRTUOSO_URL}/sparql-graph-crud-auth?graph=http://data.cimple.eu/claimreview" -T "${chunkfile}"
done

# Cleanup
echo "Cleaning up..."
rm -rf "/data/${TagName}"
rm -rf "/data/chunks"
rm "/data/${TagName}.zip"
rm "/data/claimreview-kg_${TagName}.ttl"