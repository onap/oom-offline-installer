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
    echo -e "./$(basename $0) <repository list> [destination directory]\n"
    echo "Examples:"
    echo "  ./$(basename $0) onap_3.0.0-git_repos.list ./git-repo"
}

LIST="${1}"

if [[ -z "${LIST}" ]]; then
    echo "Missing argument for repository list"
    exit 1
fi

OUTDIR="${2}"
if [[ -z "${OUTDIR}" ]]; then
    OUTDIR="./git-repo"
fi

mkdir -p "${OUTDIR}"
cd "${OUTDIR}"


while IFS=" " read -r REPO BRANCH remainder
do
        if [[ -z "${BRANCH}" ]]; then
                git clone https://${REPO} --bare ${REPO}
        else
                git clone -b ${BRANCH} --single-branch https://${REPO} --bare ${REPO}
        fi
done < <(awk '$1 ~ /^[^;#]/' ${LIST})


exit 0
