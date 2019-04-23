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
IMG_DIR="${2}"

if [[ -z "$IMG_DIR" ]]; then
    IMG_DIR="./images"
fi

echo "Creating ${IMG_DIR}"
if [[ ! -d "${IMG_DIR}" ]]; then
    mkdir -p "${IMG_DIR}"
fi

save_image() {
    local name_tag=$1
    echo "$name_tag"
    local img_name=$(echo "${name_tag}" | tr /: __)
    local img_path="${IMG_DIR}/${img_name}.tar"

    if [[ ! -f "${img_path}" ]] ; then
        echo "[DEBUG] save ${name_tag} to ${img_path}"
        echo "${name_tag}" >> $IMG_DIR/_image_list.txt
        retry docker -l error save -o "${img_path}" ${name_tag}
    else
        echo "[DEBUG] ${name_tag} already saved"
    fi
}

echo "Save all images"
line=1
lines=$(clean_list "$LIST_FILE" | wc -l)
for image in $(clean_list "$LIST_FILE"); do
    echo "== pkg #$line of $lines =="
    save_image "${image}"
    line=$((line+1))
done