#!/bin/sh

# Check that "url" was passed to the script
if [ -z "${url}" ]; then
  echo "[REDEPLOY] URL not found"
  exit 1
fi

echo "Url: $url"

TagName=$(basename "$url")
DownloadURL=$(printf "%s" "$url" | sed "s/tag/download/")/${TagName}.zip

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
  cd /data/converter || exit
else
  echo "[REDEPLOY] Updating converter scripts..."
  cd /data/converter || exit
  git pull
fi

export PYTHONUNBUFFERED=1

# Install dependencies
pip install --extra-index-url https://download.pytorch.org/whl/cpu -q -r requirements.txt

# Convert to RDF/Turtle
echo "[REDEPLOY] Converting to RDF/Turtle..."
[ -d /data/cache ] || mkdir /data/cache
python -u update_KG.py -q -i "/data/${TagName}" -o "/data/claimreview-kg_${TagName}.nt" -f "nt" -c "/data/cache" -g "/data/cache/claim-review.nt"

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
/scripts/create-release.sh "/data/claimreview-kg_${TagName}.nt" "${TagName}"

# Cleanup
echo "[REDEPLOY] Cleaning up..."
rm -rf "/data/${TagName}"
rm -rf "/data/chunks"
rm "/data/${TagName}.zip"
