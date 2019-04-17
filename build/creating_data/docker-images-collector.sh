#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE
#
#   Copyright 2019 © Samsung Electronics Co., Ltd.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
#   COPYRIGHT NOTICE ENDS HERE

### This script is preparing docker images list based on kubernetes project

### NOTE: helm needs to be installed and working, it is required for correct processing
### of helm charts in oom directory

# Fail fast settings
set -e

usage () {
    echo "      "
    echo "  This script is preparing docker images list based on kubernetes project"
    echo "      Usage:"
    echo "        ./$(basename $0) <project version> <path to project> [<output list file>]"
    echo "      "
    echo "      Example: ./$(basename $0) onap_3.0.2 /root/oom/kubernetes/onap"
    echo "      "
    echo "      Dependencies: helm, python-yaml, make"
    echo "      "
    exit 1
}

parse_yaml() {
python - <<PYP
#!/usr/bin/python
from __future__ import print_function
import yaml
import sys

with open("${1}", 'r') as f:
    values = yaml.load(f)

    enabled = filter(lambda x: values[x].get('enabled', False) == True, values)
    print(' '.join(enabled))
PYP
}

create_list() {
    helm template "${PROJECT_DIR}/../${1}" | grep 'image:\ \|tag_version:\ \|h._image' |
        sed -e 's/^.*\"h._image\"\ :\ //; s/^.*\"\(.*\)\".*$/\1/' \
            -e 's/\x27\|,//g; s/^.*\(image\|tag_version\):\ //' | sort -u >> ${LIST}
}

# Configuration
TAG="${1}"
PROJECT_DIR="${2}"
LIST="${3}"
LISTS_DIR="$(readlink -f $(dirname ${0}))/../data_lists"
HELM_REPO="local http://127.0.0.1:8879"

if [ "${1}" == "-h" ] || [ "${1}" == "--help" ] || [ $# -lt 2 ]; then
    usage
elif [ ! -f "${PROJECT_DIR}/../Makefile" ]; then
    echo "Wrong path to project directory entered"
    exit 1
elif [ -z "${LIST}" ]; then
    mkdir -p ${LISTS_DIR}
    LIST="${LISTS_DIR}/${TAG}-docker_images.list"
fi

if [ -e "${LIST}" ]; then
    mv -f "${LIST}" "${LIST}.bk"
    MSG="$(realpath ${LIST}) already existed\nCreated backup $(realpath ${LIST}).bk\n"
fi

PROJECT="$(basename ${2})"

# Setup helm
if pgrep -x "helm" > /dev/null; then
    echo "helm is already running"
else
    helm init -c > /dev/null
    helm serve &
fi

# Create helm repository
if ! helm repo list 2>&1 | awk '{ print $1, $2 }' | grep -q "$HELM_REPO" > /dev/null; then
    helm repo add "$HELM_REPO"
fi

# Make all
pushd "${PROJECT_DIR}/.."
echo "Building project..."
make all > /dev/null; make ${PROJECT} > /dev/null
popd

# Create the list from all enabled subsystems
if [ "${PROJECT}" == "onap" ]; then
    for subsystem in `parse_yaml "${PROJECT_DIR}/values.yaml"`; do
        create_list ${subsystem}
    done
else
    create_list ${PROJECT}
fi

echo ${MSG}
echo -e 'The list have been created:\n '"${LIST}"
exit 0