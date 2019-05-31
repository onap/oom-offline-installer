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

#   This simple script should be used during build / packaging process
#   and it should be referenced in BuildGuide.
#   Patching of helm charts is the only way for OOM charts to be compatible
#   with this offline installer. This will become obsolete once native
#   solution is implemented in charts themselves and which is tracked
#   in OOM-1610

# fail fast
set -e

# colours
_R='\033[0;31;1m'       #Red
_G='\033[0;32;1m'       #Green
_Y='\033[0;33;1m'       #Yellow
C_='\033[0m'            #Color off

usage () {
    echo "Usage:"
    echo -e "./$(basename $0) <helm charts repo> <commit/tag/branch> <patchfile> <target_dir>\n"
    echo "Example: ./$(basename $0) https://gerrit.onap.org/r/oom master /root/offline-installer/patches/onap.patch /root/offline-installer/ansible/application/helm_charts"
}

if [ "$#" -ne 4 ]; then
    echo "This script should get exactly 4 arguments!"
    echo -e "Wrong number of parameters provided\n"
    usage
    exit 1
fi

# main
# git and patch tools are preconditions for this to work
CURR=1
TOTAL=5
PATCH_FILE=$(realpath "${3}")

echo -e "${_G}[Step $((CURR++))/${TOTAL} cloning repo with charts to be patched]${C_}"
git clone --recurse-submodules "${1}" "${4}"

echo -e "${_G}[Step $((CURR++))/${TOTAL} setting working dir to ${4}]${C_}"
pushd "${4}"

echo -e "${_G}[Step $((CURR++))/${TOTAL} git-checkout to correct base]${C_}"
git checkout "${2}"

echo -e "${_G}[Step $((CURR++))/${TOTAL} patching charts]${C_}"
git apply "${PATCH_FILE}"

echo -e "${_G}[Step $((CURR++))/${TOTAL} returning to original working directory]${C_}"
popd

