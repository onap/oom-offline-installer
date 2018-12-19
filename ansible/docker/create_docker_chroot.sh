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

CMD=$(basename "$0")

help()
{
    echo "
NAME:
    ${CMD} - create a chroot directory from docker image

DESCRIPTION:
    It will export docker image into a directory capable of chrooting.
    It needs and will run these commands (requires docker service):
        docker create
        docker export

USAGE:
    ${CMD} [-h|--help|help]
        This help

    ${CMD} convert <docker-name> <name-of-directory>

        It will convert docker image into directory - no chroot yet.
        The name of the docker image must be imported already (not a file):
            docker image ls

        The directory will be created and so this command will fail if some
        directory or a file of this name (filepath) already exists!
        There is another script run_chroot.sh with which you can do chroot
        on this newly created directory - so it is expected that this
        directory is kept clean and as it is.
        If you don't care about this feature (run_chroot.sh) and you know
        what are you doing, then do necessary mounts and execute:
            chroot <name-of-directory>/chroot /bin/sh -l
"
}

#
# PLEASE DON'T TOUCH ME
#

# readme file for run_chroot.sh
readme()
{
    md_codequote='```'

cat > "$CHROOT_METADIR"/README.md <<EOF
# RUN CHROOT COMMAND

# usage:

${md_codequote}
run_chroot.sh help
${md_codequote}

**Don't modify insides of this directory (where this README.md lies).**

The structure is needed as it is.

If you wish to just run chroot by yourself, you can do:
${md_codequote}
chroot ./chroot /bin/sh -l
${md_codequote}

# requirements:

* root privileges
* docker service

# directory structure:
${md_codequote}
   README.md
   chroot/
   .overlay
   .workdir
   .merged
${md_codequote}
EOF
}

# arg: <docker-name>
check_docker_image()
{
    image="$1"
    match=$(docker image ls --no-trunc -q "$image" | wc -l)

    case $match in
        0)
            echo ERROR: "Docker image does not exist: ${DOCKER_IMAGE}" >&2
            exit 1
            ;;
        1)
            :
            ;;
        *)
            echo ERROR: "Multiple results for this docker name: ${DOCKER_IMAGE}" >&2
            exit 1
            ;;
    esac

    return 0
}

cleanup()
{
    if [ -n "$DOCKER_CONTAINER" ] ; then
        echo INFO: "Delete the export container: ${DOCKER_CONTAINER}" >&2
        if ! docker rm "$DOCKER_CONTAINER" > /dev/null ; then
            echo ERROR: "Failed to delete: ${DOCKER_CONTAINER}" >&2
        fi
    fi
}

on_exit()
{
    set +e
    cleanup
}

action=nil
case "$1" in
    ''|-h|--help|help)
        help
        exit 0
        ;;
    convert)
        action=convert
        DOCKER_IMAGE="$2"
        CHROOT_METADIR="$3"
        ;;
    *)
        echo ERROR: "Bad usage" >&2
        help >&2
        exit 1
        ;;
esac


case "$action" in
    ''|nil)
        echo ERROR: "Nothing to do - missing command" >&2
        help >&2
        exit 1
        ;;
    convert)
        if [ -z "$DOCKER_IMAGE" ] || [ -z "$CHROOT_METADIR" ] ; then
            echo ERROR: "Missing argument" >&2
            help >&2
            exit 1
        fi

        if [ -e "$CHROOT_METADIR" ] ; then
            echo ERROR: "Filepath already exists: ${CHROOT_METADIR}" >&2
            echo ERROR: "Please rename it, remove it or use different name" >&2
            echo ERROR: "I need my working directory empty, thanks" >&2
            exit 1
        fi

        # check if docker image is there
        check_docker_image "$DOCKER_IMAGE"

        # we must be root
        if [ "$(id -u)" -ne 0 ] ; then
            echo ERROR: "I need root privileges and you are not root: $(id -nu)" >&2
            exit 1
        fi

        # making sure that CHROOT_METADIR is absolute path
        CHROOT_METADIR=$(readlink -f "$CHROOT_METADIR")

        # set trap
        trap on_exit INT QUIT TERM EXIT

        # making readme
        mkdir -p "$CHROOT_METADIR"/
        readme

        # create container
        DOCKER_CONTAINER=$(docker create "$DOCKER_IMAGE")
        if [ -z "$DOCKER_CONTAINER" ] ; then
            echo ERROR: "I could not create a container from: ${DOCKER_IMAGE}" >&2
            exit 1
        fi

        # unpacking of image
        mkdir -p "$CHROOT_METADIR"/chroot
        echo INFO: "Export started - it can take a while to finish..." >&2
        if ! docker export "$DOCKER_CONTAINER" | tar -C "$CHROOT_METADIR"/chroot -xf - ; then
            echo ERROR: "Unpacking failed - permissions?" >&2
            exit 1
        else
            echo INFO: "Export success: $CHROOT_METADIR/chroot" >&2
            echo INFO: "Checkout the README file: $CHROOT_METADIR/README.md" >&2
        fi
        ;;
esac

exit 0

