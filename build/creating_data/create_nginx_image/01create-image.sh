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

VERSION="$(cat $(dirname ${0})/VERSION)"

IMG_DIR="${1}"

if [[ ! -e $IMG_DIR ]]; then
    mkdir -p "${IMG_DIR}"
fi

script_dir="$(dirname ${BASH_SOURCE[0]})"
cd "$script_dir"
docker build -t own_nginx:${VERSION} .
docker -l error save -o "$IMG_DIR/own_nginx_${VERSION}.tar" "own_nginx:${VERSION}"
exit 0
