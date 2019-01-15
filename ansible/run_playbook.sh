#!/bin/sh

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

script_path=$(readlink -f "$0")
script_name=$(basename "$script_path")
ANSIBLE_DIR=$(dirname "$script_path")
ANSIBLE_CHROOT="${ANSIBLE_DIR}/ansible_chroot"
ANSIBLE_LOG_PATH="/ansible/log/ansible-$(date +%Y.%m.%d-%H%M%S).log"


#
# functions
#

help()
{
    echo "
NAME:
    ${script_name} - wrapper for ansible-playbook command

DESCRIPTION:
    Run ansible playbook (or other command if it is there) inside a docker
    container or a chroot environment.

    By default the chroot is used because it has less dependencies and no
    service needs to be run (provided that chroot command is installed).

    Docker support is kept for compatibility reasons.

    To run ansible docker image you must set environment variable:
        ANSIBLE_DOCKER_IMAGE

    So this wrapper can know by which name you have built the included
    Dockerfile and also to trigger this different behaviour.

    For example:
        ANSIBLE_DOCKER_IMAGE=ansible

USAGE:
    ./${script_name}
        This help

    ./${script_name} <args>
        Run ansible-playbook command inside a chroot

    ANSIBLE_DOCKER_IMAGE=<docker-image> ./${script_name} <args>
        Run ansible-playbook command inside a docker container

REQUIREMENTS:
    For the optimal usage your system should support overlay mount. Which
    should be available on any recent kernel at least couple of years back.

    Another requirement is the 'unshare' utility which is part of 'util-linux'
    package and also is part of system for couple of years already.

    The last is 'chroot' command itself and that is also part of system
    basically everywhere.
"
}


#
# run playbook
#

export ANSIBLE_LOG_PATH

# if no arg then print help and exit
if [ -z "$1" ] ; then
    help
    exit 0
fi

# we must be root
if [ "$(id -u)" -ne 0 ] ; then
    echo ERROR: "I need root privileges and you are not root: $(id -nu)" >&2
    exit 1
fi

# if env var is set then run in docker
if [ -n "$ANSIBLE_DOCKER_IMAGE" ] ; then
    exec docker run --rm \
        -v "${HOME}"/.ssh:/root/.ssh:rw \
        -v "$ANSIBLE_DIR:/ansible:ro" \
        -v "$ANSIBLE_DIR/application:/ansible/application:rw" \
        -v "$ANSIBLE_DIR/certs/:/certs:rw" \
        -v "$ANSIBLE_DIR/log/:/ansible/log:rw" \
        -e ANSIBLE_LOG_PATH \
        -it "${ANSIBLE_DOCKER_IMAGE}" "$@"
fi

# if not already there then unpack chroot
if ! [ -d "$ANSIBLE_CHROOT" ] ; then
    if ! [ -f "$ANSIBLE_DIR"/docker/ansible_chroot.tgz ] ; then
        echo ERROR: "Missing chroot archive: ${ANSIBLE_DIR}/ansible_chroot.tgz" >&2
        exit 1
    fi

    echo INFO: "Unpacking chroot tar into: ${ANSIBLE_CHROOT}" >&2
    if ! tar -C "$ANSIBLE_DIR" -xzf "$ANSIBLE_DIR"/docker/ansible_chroot.tgz ; then
        echo ERROR: "Unpacking failed - ABORT" >&2
        exit 1
    fi
fi

# run chroot
"$ANSIBLE_DIR"/docker/run_chroot.sh \
    --mount rw:"${HOME}/.ssh":/root/.ssh \
    --mount ro:"$ANSIBLE_DIR":/ansible \
    --mount rw:"$ANSIBLE_DIR"/application:/ansible/application \
    --mount rw:"$ANSIBLE_DIR"/log:/ansible/log \
    --mount rw:"$ANSIBLE_DIR"/certs:/certs \
    --mount ro:/etc/resolv.conf:/etc/resolv.conf \
    --mount ro:/etc/hosts:/etc/hosts \
    --workdir /ansible \
    execute "$ANSIBLE_CHROOT" ansible-playbook "$@"

exit 0
