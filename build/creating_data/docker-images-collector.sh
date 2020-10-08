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
    echo "        ./$(basename $0) <path to project> [<output list file>]"
    echo "      "
    echo "      Example: ./$(basename $0) /root/oom/kubernetes/onap"
    echo "      "
    echo "      Dependencies: helm, python-yaml, make"
    echo "      "
    exit 1
}

parse_yaml() {
python3 - <<PYP
#!/usr/bin/python3
import yaml
import sys

with open("${1}", 'r') as f:
    values = yaml.load(f, Loader=yaml.SafeLoader)
    enabled = filter(lambda x: values[x].get('enabled', False) == True, values)
    print(' '.join(enabled))
PYP
}

create_list() {
    if [ -d "${PROJECT_DIR}/../${1}" ]; then
        SUBSYS_DIR="${PROJECT_DIR}/../${1}"
    elif [ -d "${PROJECT_DIR}/../common/${1}" ]; then
        SUBSYS_DIR="${PROJECT_DIR}/../common/${1}"
    else
        >&2 echo -e \n"    !!! ${1} sybsystem does not exist !!!"\n
    fi
    helm template --set global.masterPassword=TemplatePassword -f ${PROJECT_DIR}/values.yaml "${SUBSYS_DIR}" | grep 'image:\ \|tag_version:\ \|h._image' |
        sed -e 's/^.*\"h._image\"\ :\ //; s/^.*\"\(.*\)\".*$/\1/' \
            -e 's/\x27\|,//g; s/^.*\(image\|tag_version\):\ //' | tr -d '\r'
}

# Configuration
if [ "${1}" == "-h" ] || [ "${1}" == "--help" ] || [ $# -lt 1 ]; then
    usage
fi

PROJECT_DIR="${1}"
LIST="${2}"
LISTS_DIR="$(readlink -f $(dirname ${0}))/../data_lists"
HELM_REPO="local http://127.0.0.1:8879"
PROJECT="$(basename ${1})"

if [ ! -f "${PROJECT_DIR}/../Makefile" ]; then
    echo "Wrong path to project directory entered"
    exit 1
elif [ -z "${LIST}" ]; then
    mkdir -p ${LISTS_DIR}
    LIST="${LISTS_DIR}/${PROJECT}_docker_images.list"
else
    # $2 is not empty - ensure LIST path exists
    LIST_DIR="$(dirname ${LIST})"
    mkdir -p "${LIST_DIR}"
    MSG="${LIST_DIR} didn't exist, created\n"
fi

if [ -e "${LIST}" ]; then
    mv -f "${LIST}" "${LIST}.bk"
    MSG="$(realpath ${LIST}) already existed\nCreated backup $(realpath ${LIST}).bk\n"
fi

# Setup helm
if ps -eaf | grep -v "grep" | grep "helm" > /dev/null; then
    echo "helm is already running"
else
    helm init -c > /dev/null
    helm serve &
    helm repo remove stable
fi

# Create helm repository
if ! helm repo list 2>&1 | awk '{ print $1, $2 }' | grep -q "$HELM_REPO" > /dev/null; then
    helm repo add $HELM_REPO
fi

# Make all
pushd "${PROJECT_DIR}/.."
echo "Building project..."
make all > /dev/null; make ${PROJECT} > /dev/null
popd

# Create the list from all enabled subsystems
echo "Creating the list..."
if [ "${PROJECT}" == "onap" ]; then
    COMMENT="OOM commit $(git --git-dir="${PROJECT_DIR}/../../.git" rev-parse HEAD)"
    for subsystem in `parse_yaml "${PROJECT_DIR}/resources/overrides/onap-all.yaml"`; do
        create_list ${subsystem}
    done | sort -u > ${LIST}
else
    COMMENT="${PROJECT}"
    create_list ${PROJECT} | sort -u > ${LIST}
fi

# Add comment reffering to the project
sed -i "1i# generated from ${COMMENT}" "${LIST}"

echo -e ${MSG}
echo -e 'The list has been created:\n '"${LIST}"
exit 0
