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

### This script is collecting docker images from oom project

### helm is required

tag="${1}"
list="${2}"

# Convert tag/version to oom used format
branch="$(sed -e 's/^\(.*\)_\(.*\)/\U\2\-\1/' <<< ${tag})"
app="$(sed 's/_.*$//' <<< ${tag})"
lists_dir="$(readlink -f $(dirname ${0}))/data_lists"

usage () {
    echo "  This script is preparing docker images list based on oom project"
    echo "      Usage:"
    echo "        ./$(basename $0) <tag/version> [<output list file>]"
    echo "      "
    echo "      Example: ./$(basename $0) onap_3.0.1  /root/docker_image.list"
    echo "      "
    echo "      Dependency: helm"
    echo "      "
    exit 1
}

parse_yaml() {
python - <<PYP
#!/usr/bin/python
from __future__ import print_function
import yaml
import sys

with open("${1}", 'r') as f:
    values = yaml.load(f)

    enabled = filter(lambda x: values[x].get('enabled', False) == True, values)
    print(' '.join(enabled))
PYP
}

# Configuration check
if [ "${1}" == "-h" ] || [ -z "${1}" ]; then
    usage
elif [[ ! -z "${2}" ]]; then
    mkdir -p "${lists_dir}"
    list="${lists_dir}/${tag}-docker_images.list"
else
    echo "Missing mandatory parameter!"
    usage
    exit 1
fi

# Clone oom repository
git clone -b ${branch} http://gerrit.onap.org/r/oom
cd oom/kubernetes

# Setup helm
helm init
helm serve &
helm repo remove stable local
helm repo add local http://127.0.0.1:8879

# Make all
make all; make onap

# Create the list from all enabled subsystems
for subsystem in `parse_yaml "${app}/values.yaml"`; do
    helm template "$(dirname ${app})/${subsystem}" | grep 'image:\ \|tag_version:\ \|h._image' |
    sed -e 's/^.*\"h._image\"\ :\ //; s/^.*\"\(.*\)\".*$/\1/' \
        -e 's/\x27\|,//g; s/^.*\(image\|tag_version\):\ //'
done |

sort -u> ${list}

exit 0