#!/bin/sh

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

    http_code=$(curl -s -o release.json -w '%{http_code}' \
           --request POST \
           --header "Authorization: Bearer ${token}" \
           --header "Content-Type: application/octet-stream" \
           --data "{\"tag_name\": \"${tag}\", \"name\": \"${name}\", \"body\": \"Full release from ${name}\" }" \
           "https://api.github.com/repos/$user/$repo/releases")
    if [ "${http_code}" = "201" ]; then
        echo "Created release:"
        cat release.json
    else
        echo "Create release failed with code '${http_code}':"
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
    if [ "${http_code}" = "201" ]; then
        echo "Asset ${name} uploaded:"
        jq -r .browser_download_url upload.json
    else
        echo "Upload failed with code '${http_code}':"
        cat upload.json
        return 1
    fi
}

# Make sure a path was passed in
if [ $# -eq 0 ]; then
    echo "Usage: ${0} <path to directory to compress>"
    exit 1
fi

# Make sure the path exists
if [ ! -d "${1}" ]; then
    echo "Error: ${1} is not a directory."
    exit 1
fi

# Check for valid github token
if [ -z "${GITHUB_TOKEN}" ]; then
    echo "Error: GITHUB_TOKEN is not set."
    exit 1
fi

# Create a .tar.gz file and upload it into a new release
dt=$(date '+%Y-%m-%d')
compressed_file="${dt}.tar.gz"
echo "Compressing ${1} into ${compressed_file}"
tar -czvf "${compressed_file}" -C "${1}" .
if create_release "CIMPLE-project" "knowledge-base" "${GITHUB_TOKEN}" "${dt}" "${dt}" ; then
    upload_release_file "${GITHUB_TOKEN}" "${compressed_file}" "${compressed_file}"
    rm "upload.json"
    rm "release.json"
fi
rm "${compressed_file}"