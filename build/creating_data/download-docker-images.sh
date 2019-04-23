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


# Load common-functions library
. $(dirname ${0})/../common-functions.sh

LIST_FILE="${1}"
if [[ -z "$LIST_FILE" ]]; then
    LIST_FILE="docker_image_list.txt"
fi

echo "Download all images"

lines=$(clean_list "$LIST_FILE" | wc -l)
line=1
for image in $(clean_list "$LIST_FILE"); do
    echo "== pkg #$line of $lines =="
    echo "$image"
    retry docker -l error pull "$image"
    line=$((line+1))
done
