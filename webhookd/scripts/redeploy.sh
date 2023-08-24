#!/bin/bash

echo "Url: $url"

TagName="${url##*/}"
DownloadURL="${url/tag/download}/${TagName}.zip"

[ -z "${VIRTUOSO_URL}" ] && { echo "Missing environment variable VIRTUOSO_URL"; exit 1; }
[ -z "${TagName}" ] && { echo "TagName not found from URL"; exit 1; }

# Download the archive
if [ ! -d "/data/${TagName}" ]; then
  echo "$DownloadURL"
  curl -L -o "${TagName}.zip" "$DownloadURL"
  unzip "${TagName}.zip" -d /data
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
python update_KG.py -i "/data/${TagName}" -o "/data/claimreview-kg_${TagName}.ttl" -c "/data/cache"

# Deploy to KB
echo "Deploying to KB..."
curl --digest --user dba:deployclaimreview. --verbose --url "${VIRTUOSO_URL}/sparql-graph-crud-auth?graph=http://data.cimple.eu/claimreview" -T "/data/claimreview-kg_${TagName}.ttl"

# Cleanup
echo "Cleaning up..."
rm -rf "/data/${TagName}"
rm "/data/claimreview-kg_${TagName}.ttl"