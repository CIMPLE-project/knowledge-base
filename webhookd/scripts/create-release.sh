#!/bin/sh

# query the SPARQL endpoint for statistics to include in the release
query_statistics() {
    endpoint="https://data.cimple.eu/sparql"
    query=$(cat "$(dirname "$0")/statistics_query.rq")

    result=$(curl -s --data-urlencode "query=${query}" "${endpoint}" \
             -H "Accept: application/sparql-results+json")

    nb_claims=$(echo "${result}" | jq -r '.results.bindings[0].nbClaim.value')
    nb_organizations=$(echo "${result}" | jq -r '.results.bindings[0].nbOrganizations.value')
    nb_languages=$(echo "${result}" | jq -r '.results.bindings[0].nbLanguages.value')
    nb_entities=$(echo "${result}" | jq -r '.results.bindings[0].nbEntities.value')

    echo "${nb_claims},${nb_organizations},${nb_languages},${nb_entities}"
}

# create a new release
# user: user's name
# repo: the repo's name
# token: github api user token
# tag: name of the tag pushed
create_release() {
    user=$1
    repo=$2
    token=$3
    tag=$4
    name=$5

    # Query the SPARQL endpoint for statistics
    stats=$(query_statistics)
    nb_claims=$(echo "$stats" | awk -F, '{print $1}')
    nb_organizations=$(echo "$stats" | awk -F, '{print $2}')
    nb_languages=$(echo "$stats" | awk -F, '{print $3}')
    nb_entities=$(echo "$stats" | awk -F, '{print $4}')

    # Create a markdown table with the stats
    stats_table="| Metric | Value |\n| --- | --- |\n| Number of Claims | ${nb_claims} |\n| Number of Organizations | ${nb_organizations} |\n| Number of Languages | ${nb_languages} |\n| Number of Entities | ${nb_entities} |"

    http_code=$(curl -s -o release.json -w '%{http_code}' \
           --request POST \
           --header "Authorization: Bearer ${token}" \
           --header "Content-Type: application/json" \
           --data "{\"tag_name\": \"${tag}\", \"name\": \"${name}\", \"body\": \"Daily release from ${name}\n\n${stats_table}\" }" \
           "https://api.github.com/repos/$user/$repo/releases")
    if [ "${http_code}" -ge 200 ] && [ "${http_code}" -lt 300 ]; then
        echo "[CREATE-RELEASE] Created release:"
        cat release.json
    else
        echo "[CREATE-RELEASE] Create release failed with code '${http_code}':"
        cat release.json
        return 1
    fi
}

# upload a release file.
# this must be called only after a successful create_release, as create_release saves
# the json response in release.json.
# token: github api user token
# file: path to the asset file to upload
# name: name to use for the uploaded asset
upload_release_file() {
    token=$1
    file=$2
    name=$3

    url=$(jq -r .upload_url release.json | cut -d'{' -f1)
    http_code=$(curl -s -o upload.json -w '%{http_code}' \
           --request POST \
           --header "Authorization: Bearer ${token}" \
           --header "Content-Type: application/octet-stream" \
           --data-binary @"${file}" \
           "${url}?name=${name}")
    if [ "${http_code}" -ge 200 ] && [ "${http_code}" -lt 300 ]; then
        echo "[CREATE-RELEASE] Asset ${name} uploaded:"
        jq -r .browser_download_url upload.json
    else
        echo "[CREATE-RELEASE] Upload failed with code '${http_code}':"
        cat upload.json
        return 1
    fi
}

# Check for parameters
if [ -z "${1}" ]; then
    echo "[CREATE-RELEASE] Missing parameter: file_path"
    exit 1
fi
if [ -z "${2}" ]; then
    echo "[CREATE-RELEASE] Missing parameter: release_name"
    exit 1
fi

# Create a gzip file and upload it into a new release
release_name="${2}"
compressed_file="${1}.gz"
echo "[CREATE-RELEASE] Compressing ${1} into ${compressed_file}"
gzip -c "${1}" > "${compressed_file}"
create_release "CIMPLE-project" "knowledge-base" "${GITHUB_TOKEN}" "${release_name}" "${release_name}"
upload_release_file "${GITHUB_TOKEN}" "${compressed_file}" "${compressed_file}"

echo "[CREATE-RELEASE] Cleaning up..."
rm -f "${compressed_file}"
rm -f "upload.json"
rm -f "release.json"
