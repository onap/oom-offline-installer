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
if [ $(id -u ${USER}) -eq "0" ]; then DOCKER_USER="root"; else DOCKER_USER="molecule"; fi

set -e

docker build \
    --build-arg USER_ID=$(id -u ${USER}) \
    --build-arg GROUP_ID=$(id -g ${USER}) \
    --build-arg DOCKER_GROUP_ID=$(getent group docker | cut -f 3 -d ':') \
    --build-arg DOCKER_USER=${DOCKER_USER} \
    -t molecule-dev:2.20.0 \
    ${LOCAL_PATH}

