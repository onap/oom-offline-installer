#!/bin/bash

tag="${1}"
list="${2}"
branch="$(sed -e 's/^\(.*\)_\(.*\)/\U\2\-\1/' <<< ${tag})"
app="$(sed 's/_.*$//' <<< ${tag})"
lists_dir="$(readlink -f $(dirname ${0}))/data_lists"

usage () {
    echo "  This script is preparing docker images list based on oom project"
    echo "      Usage:"
    echo "        ./$(basename $0) <tag/version> [<output list file>]"
    echo "      "
    echo "      Example: ./$(basename $0) onap_3.0.1  /root/docker_image.list"
    echo "      "
    exit 1
}

parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_-]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

# Configuration check
if [ "${1}" == "-h" ] || [ -z "${1}" ]; then
    usage
elif [ -z "${2}" ]; then
    mkdir -p "${lists_dir}"
    list="${lists_dir}/${tag}-docker_images.list"
else
    echo "Missing mandatory parameter!"
    usage
    exit 1
fi

# Clone repository
git clone -b ${branch} http://gerrit.onap.org/r/oom
cd oom/kubernetes

# Setup helm
helm init
helm serve &
helm repo remove stable local
helm repo add local http://127.0.0.1:8879

# Make all
make all; make onap

# Create the list from all enabled subsystems
for subsystem in `parse_yaml "${app}/values.yaml" | grep 'enabled="true"' | sed 's/_.*$//g'`; do
    helm template "$(dirname ${app})/${subsystem}" | grep 'image:\ \|tag_version:\ \|h._image' | 
    sed -e 's/^.*\"h._image\"\ :\ //; s/^.*\"\(.*\)\".*$/\1/' \
        -e 's/\x27\|,//g; s/^.*\(image\|tag_version\):\ //'
done |

sort -u> ${list}

exit 0