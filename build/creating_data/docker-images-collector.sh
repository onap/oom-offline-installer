#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE
#
#   Copyright 2019-2021 © Samsung Electronics Co., Ltd.
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

### This script is preparing docker images list based on OOM project

### NOTE: helm and docker need to be installed; those are required for correct processing
### of helm charts in oom directory; helm push plugin is also  required if
### using helm v3

# Fail fast settings
set -e

usage () {
    echo "      "
    echo "  This script is preparing docker images list based on OOM project"
    echo "      Usage:"
    echo "        ./$(basename $0) [OPTION]... <path to project> [<output list file>]"
    echo "      "
    echo "      Options:"
    echo "          -h | --help            Show script usage synopsis"
    echo "          -p | --helm-port       Chart repository server port"
    echo "          -b | --helm-bin        Path to Helm executable"
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
    ${HELM_BIN} template --set global.masterPassword=TemplatePassword,global.offlineDeploymentBuild=true -f ${PROJECT_DIR}/values.yaml "${SUBSYS_DIR}" | grep 'image:\ \|tag_version:\ \|h._image' |
        sed -e 's/^.*\"h._image\"\ :\ //; s/^.*\"\(.*\)\".*$/\1/' \
            -e 's/\x27\|,//g; s/^.*\(image\|tag_version\):\ //' | tr -d '\r'
}

# Kill helm repository if already running
kill_chart_repo() {
    if [[ "${HELM_VERSION}" =~ "v3" ]];
    then
        if [ $(docker ps -aq -f name="^chartmuseum-${HELM_REPO_PORT}$") ];
        then
            docker kill "chartmuseum-${HELM_REPO_PORT}"
        fi
    else
        for pid in $(pgrep -f "${HELM_BIN} serve --address ${HELM_REPO}");
        do
            # Kill helm repository server process
            kill $pid
        done
    fi
}

validate_port() {
    if [ -z $1 ];
    then
        echo "Error: No valid port number provided"
        exit 1
    fi
    if ! [[ "$1" =~ ^[0-9]*$ ]];
    then
        echo "Error: "${1}" is not a valid port number"
        exit 1
    fi
}

validate_bin() {
    if [ -z $1 ];
    then
        echo "Error: No path to executable provided"
        exit 1
    else
        if ! [[ -x ${1} && -f ${1} ]];
        then
            echo "Error: ${1} is not an executable"
            exit 1
        fi
    fi
}

check_chart_repo() {
    sleep 2 # let the helm repository process settle
    if [[ "${HELM_VERSION}" =~ "v3" ]];
    then
        if [ ! $(docker ps -aq -f name="^chartmuseum-${HELM_REPO_PORT}$") ];
        then
            echo "Fatal: Helm chart repository docker container failed to start"
            exit 1
        fi
    else
        if [ $(pgrep -f "${HELM_BIN} serve --address ${HELM_REPO}" -c) -eq 0 ];
        then
            echo "Fatal: Helm chart repository server failed to start"
            exit 1
        fi
    fi
}

# Proccess input options
if [ $# -lt 1 ]; then
    usage
fi

while [ $# -gt 0 ];
do
    case "${1}" in
        -h | --help)
            usage
            ;;
        -p | --helm-port)
            PORT="${2}"
            validate_port "${PORT}"
            shift 2
            ;;
        -b | --helm-bin)
            BIN="${2}"
            validate_bin "${BIN}"
            shift 2
            ;;
        -*)
            echo "Unknown option ${1}"
            usage
            ;;
        *)
            # end of options
            break
            ;;
    esac
done

# Configuration
PROJECT_DIR="${1}"
LIST="${2}"
LISTS_DIR="$(readlink -f $(dirname ${0}))/../data_lists"
HELM_BIN=${BIN:-helm}
HELM_REPO_HOST="127.0.0.1"
HELM_REPO_PORT="${PORT:-8879}"
HELM_REPO="${HELM_REPO_HOST}:${HELM_REPO_PORT}"
HELM_REPO_PATH="dist/packages" # based on PACKAGE_DIR defined in oom/kubernetes/Makefile
HELM_VERSION=$(${HELM_BIN} version -c --template "{{.Version}}")
DOCKER_CONTAINER="generate-certs-${HELM_REPO_PORT}" # oom-cert-service container name override
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

HELM_HOME=$(mktemp -p /tmp -d .helm.XXXXXXXX)
export HELM_HOME

kill_chart_repo # make sure it's not already running
if [[ "${HELM_VERSION}" =~ "v3" ]];
then
    # Setup helm v3
    export HELM_CONFIG_HOME="${HELM_HOME}/.config"
    export HELM_CACHE_HOME="${HELM_HOME}/.cache"
    mkdir --mode=777 ${HELM_HOME}/chartmuseum
    docker run --rm -it -d -p ${HELM_REPO_PORT}:8080 \
      --name "chartmuseum-${HELM_REPO_PORT}" \
      -e STORAGE=local -e STORAGE_LOCAL_ROOTDIR=/charts \
      -v ${HELM_HOME}/chartmuseum:/charts chartmuseum/chartmuseum
    sleep 2 # let the chartmuseum process settle
    ${HELM_BIN} repo add local "http://${HELM_REPO}"
else
    # Setup helm v2
    mkdir -p "${PROJECT_DIR}/../${HELM_REPO_PATH}"
    ${HELM_BIN} init --skip-refresh -c --local-repo-url "http://${HELM_REPO}"
    ${HELM_BIN} serve --address ${HELM_REPO} --repo-path "${PROJECT_DIR}/../${HELM_REPO_PATH}" &
    ${HELM_BIN} repo remove stable 2>/dev/null || true
fi
check_chart_repo

# Make all
pushd "${PROJECT_DIR}/.."
echo "Building project..."
export SKIP_LINT=TRUE
export DOCKER_CONTAINER
export HELM_BIN
make -e all > /dev/null; make -e ${PROJECT} > /dev/null
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

# Kill helm
kill_chart_repo
# Remove temporary helm directory
rm -rf ${HELM_HOME}

exit 0
