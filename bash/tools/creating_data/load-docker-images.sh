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


# boilerplate
RELATIVE_PATH=../ # relative path from this script to 'common-functions.sh'
if [ "$IS_COMMON_FUNCTIONS_SOURCED" != YES ] ; then
    SCRIPT_DIR=$(dirname "${0}")
    LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")
    . "${LOCAL_PATH}"/"${RELATIVE_PATH}"/common-functions.sh
fi

CLEAN=false

if [ -z "$NEXUS_HOST" ]; then
    echo "Independent run for inserting of additional docker images"
    CLEAN=true
    mv ~/.docker/config.json ~/.docker/config.json_backup 2>/dev/null
    source "$LOCAL_PATH/docker-login.sh"
fi

IMG_DIR="$1"
if [[ -z "$IMG_DIR" ]]; then
    IMG_DIR="$(pwd)/images"
fi

if [[ ! -d "${IMG_DIR}" ]]; then
    echo "No ${IMG_DIR} to load images"
    exit 0
fi

load_image() {
    local image="$1"
    echo "[DEBUG] load ${image}"
    result=$(docker load -i "${image}")
    echo $result
    name=$(echo $result | awk '{print $3}')
    echo "[DEBUG] pushing $name"
    retry docker push "$name"
    # delete pushed image from docker
    retry docker rmi "$name"
}

IMAGES=$(find ${IMG_DIR} -name "*.tar" -type f)
lines=$(echo ${IMAGES} | wc -l)
line=1
for image in ${IMAGES}; do
    echo "== pkg #$line of $lines =="
    load_image "$image"

    line=$((line+1))
done

if [ "$CLEAN" = true ]; then
    # onap is using different credentials for docker login which can be conflicted
    # with ours so better to clean this-up
    rm ~/.docker/config.json
fi
