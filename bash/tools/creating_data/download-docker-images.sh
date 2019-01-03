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

SRC_IMAGE_LIST=$1
if [[ -z "$SRC_IMAGE_LIST" ]]; then
    SRC_IMAGE_LIST="docker_image_list.txt"
fi

echo "Download all images"

lines=$(cat $SRC_IMAGE_LIST | wc -l)
line=1
while read -r image; do
    echo "== pkg #$line of $lines =="

    name=$(echo $image|awk '{print $1}')
    digest=$(echo $image|awk '{print $2}')

    echo "$name digest:$digest"
    if [[ "$digest" == "<none>" ]]; then
        retry docker -l error pull "$name"
    else
        retry docker -l error pull "$name"
    fi
    line=$((line+1))

done < "$SRC_IMAGE_LIST"
