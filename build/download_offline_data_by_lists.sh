#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE
#
#   Copyright 2018 © Samsung Electronics Co., Ltd.
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


# fail fast
set -e

usage () {
    echo "Usage:"
    echo -e "./$(basename $0) <project version>\n"
    echo "onap_3.0.0 for casablanca                                (sign-off 30/11/2018)"
    echo "onap_3.0.1 for casablanca maintenance release            (sign-off 10/12/2018)"
    echo "onap_3.0.2 for latest casablanca with fixed certificates (sign-off 16/04/2019)"
    echo ""
    echo "Example:"
    echo "  ./$(basename $0) onap_3.0.2"
}

# boilerplate
RELATIVE_PATH=./ # relative path from this script to 'common-functions.sh'
if [ "$IS_COMMON_FUNCTIONS_SOURCED" != YES ] ; then
    SCRIPT_DIR=$(dirname "${0}")
    LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")
    . "${LOCAL_PATH}"/"${RELATIVE_PATH}"/common-functions.sh
fi

if [ "${1}" == "-h" ] || [ -z "${1}" ]; then
    usage
    exit 0
else
    TAG="${1}"
fi

CTOOLS="${LOCAL_PATH}/creating_data"
LISTS_DIR="${LOCAL_PATH}/data_lists"
DATA_DIR="${LOCAL_PATH}/../../resources"
TOTAL=12
CURR=1

message info "Downloading started: $(date)"

echo "[Step $((CURR++))/$TOTAL Download collected docker images]"
$CTOOLS/download-docker-images.sh "${LISTS_DIR}/${TAG}-docker_images.list"

echo "[Step $((CURR++))/$TOTAL Download docker images for infra-server]"
$CTOOLS/download-docker-images.sh "${LISTS_DIR}/infra_docker_images.list"

echo "[Step $((CURR++))/$TOTAL Build own nginx image]"
$CTOOLS/create_nginx_image/01create-image.sh "${DATA_DIR}/offline_data/docker_images_infra"

echo "[Step $((CURR++))/$TOTAL Save docker images from docker cache to tarfiles]"
$CTOOLS/save-docker-images.sh "${LISTS_DIR}/${TAG}-docker_images.list" "${DATA_DIR}/offline_data/docker_images_for_nexus"

echo "[Step $((CURR++))/$TOTAL Prepare infra related images to infra folder]"
$CTOOLS/save-docker-images.sh "${LISTS_DIR}/infra_docker_images.list" "${DATA_DIR}/offline_data/docker_images_infra"

echo "[Step $((CURR++))/$TOTAL Download git repos]"
$CTOOLS/download-git-repos.sh "${LISTS_DIR}/onap_3.0.x-git_repos.list" "${DATA_DIR}/git-repo"

echo "[Step $((CURR++))/$TOTAL Download http files]"
$CTOOLS/download-http-files.sh "${LISTS_DIR}/onap_3.0.x-http_files.list" "${DATA_DIR}/http"

echo "[Step $((CURR++))/$TOTAL Download npm pkgs]"
$CTOOLS/download-npm-pkgs.sh "${LISTS_DIR}/onap_3.0.x-npm.list" "${DATA_DIR}/offline_data/npm_tar"

echo "[Step $((CURR++))/$TOTAL Download bin tools]"
$CTOOLS/download-bin-tools.sh "${DATA_DIR}/downloads"

echo "[Step $((CURR++))/$TOTAL Create RHEL repository]"
$CTOOLS/create-rhel-repo.sh "${DATA_DIR}/pkg/rhel"

echo "[Step $((CURR++))/$TOTAL Download sdnc-ansible-server packages]"
$CTOOLS/download-pip.sh "${LISTS_DIR}/onap_3.0.x-pip_packages.list" "${DATA_DIR}/offline_data/pypi"
$CTOOLS/download-files.sh "${LISTS_DIR}/deb_packages.list" "${DATA_DIR}/pkg/ubuntu/xenial"

echo "[Step $((CURR++))/$TOTAL Create APT repository]"
$CTOOLS/create-ubuntu-repo.sh "${DATA_DIR}/pkg/ubuntu/xenial"

message info "Downloading finished: $(date)"
