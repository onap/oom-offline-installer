#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE

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

#   COPYRIGHT NOTICE ENDS HERE


set -e

ansible_version="$1"
image_name="${2:-ansible:latest}"

script_path=$(readlink -f "$0")
script_dir=$(dirname "$script_path")

git_commit=$(git rev-parse --revs-only HEAD || echo N/A)
build_date=$(date -I)

if [ -z "$ansible_version" ]; then
    docker build "$script_dir" -t "${image_name}" --label "git-commit=$git_commit" --label "build-date=$build_date"
else
    docker build "$script_dir" -t "${image_name}" --label "git-commit=$git_commit" --label "build-date=$build_date" --build-arg ansible_version="$ansible_version"
fi

# Export docker image into chroot and tararchive it. It takes ~40M of space and is packaged together with sw.
if "${script_dir}"/create_docker_chroot.sh convert "${image_name}" "${script_dir}"/ansible_chroot ; then
    cd "$script_dir"
    echo INFO: "Tarring and zipping the chroot directory..." >&2
    tar -czf ansible_chroot.tgz ansible_chroot
    rm -rf "${script_dir}"/ansible_chroot
    echo INFO: "Finished: ${script_dir}/ansible_chroot.tgz" >&2
    cd -
else
    echo ERROR: "I failed to create a chroot environment" >&2
    exit 1
fi

exit 0