#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE

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

#   COPYRIGHT NOTICE ENDS HERE

SCRIPT_DIR=$(dirname "${0}")
LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")
# main root dir in this git repo (relative to this script location)
ROOT_DIR=$(cd ${LOCAL_PATH}/../../../ && pwd)/
PROJECT_ROOT_IN_CONTAINER=${PWD##${ROOT_DIR}}
# Make dir structure same in container to make localhost ssh actions to match same dirs
CONTAINER_ROOT=${ROOT_DIR}

if [ "${PWD}" == "${PROJECT_ROOT_IN_CONTAINER}" ]; then
    echo "Please run it under subdir of ${ROOT_DIR} directory"
    exit 1
fi

env_params=(--env LOCALHOST_ANSIBLE_HOST=$(hostname -I | cut -f 1 -d ' '))
env_params+=(--env LOCALHOST_ANSIBLE_USER=$(id -nu))

if [ -e "${LOCAL_PATH}/.env" ]; then
    env_file="--env-file ${LOCAL_PATH}/.env"
fi

MOLECULE_IMAGE=${MOLECULE_IMAGE:-molecule-dev}
MOLECULE_IMAGE_VERSION=${MOLECULE_IMAGE_VERSION:-2.20.0}
echo "Running molecule image: ${MOLECULE_IMAGE}:${MOLECULE_IMAGE_VERSION}"
MOLECULE_CMD=${MOLECULE_CMD:-molecule}
docker run --rm  \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${ROOT_DIR}:${CONTAINER_ROOT}:rw \
    -w ${CONTAINER_ROOT}/${PROJECT_ROOT_IN_CONTAINER} \
    "${env_params[@]}" \
    ${env_file} \
    --name ${MOLECULE_IMAGE} \
    ${MOLECULE_IMAGE}:${MOLECULE_IMAGE_VERSION} \
    ${MOLECULE_CMD} "$@"

