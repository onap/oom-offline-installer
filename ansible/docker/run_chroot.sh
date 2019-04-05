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


#
# functions
#

help()
{
    echo "
NAME:
    ${CMD} - run command in chrooted directory

DESCRIPTION:
    It will do necessary steps to be able chroot, optional mounts and it will
    run commands inside the requested chroot directory.

    It does overlay mount so nothing inside the chroot is modified - if there
    is no way to do overlay mount it will just do chroot directly - which means
    that user has power to render chroot useless - beware...

    The chroot is run in it's own namespace for better containerization.
    Therefore the utility 'unshare' is necessary requirement.

    After exiting the chroot all of those necessary steps are undone.

USAGE:
    ${CMD} [-h|--help|help]
        This help

    ${CMD} [OPTIONS] execute <chroot-directory> [<command with args>...]

        It will do some necessary steps after which it will execute chroot
        command and gives you prompt inside the chroot. When you leave the
        prompt it will undo those steps.
        On top of the ordinary chroot it will make overlay, so every change
        inside the chroot is only temporary and chroot is kept stateless -
        like inside a docker container. If there is no way to do overlay -
        ordinary chroot is done.
        Default command is: /bin/sh -l

        OPTIONS:

        --mount (ro|rw):<src-dir>:<inner-dir>
            This option will mount 'src-dir' which is full path on the host
            system into the relative path 'inner-dir' within the chroot
            directory.
            It can be mounted as read-only (ro) or read-write (rw).
            Multiple usage of this argument can be used to create complex
            hierarchy. Order is significant.
            For example:
                --mount ro:/scripts/ANSIBLE_DIR:/ansible \
                --mount rw:/scripts/ANSIBLE_DIR/app:/ansible/app
                This will mount directory ansible as read-only into chroot,
                but it's subdirectory 'app' will be writeable.

        --workdir <inner-dir>
            This will set working directory (PWD) inside the chroot.

EXAMPLE:
    ${CMD} --mount ro:/scripts/ansible:ansible \
        --mount rw:/scripts/ansible/app:ansible/app \
        --workdir /ansible execute /tmp/ansible_chroot
    # pwd
    /ansible
    # mount
    overlay on / type overlay ...
    /dev/disk on /ansible type ext4 (ro,relatime,errors=remount-ro)
    /dev/disk on /ansible/application type ext4 (rw,relatime,errors=remount-ro)
    none on /proc type proc (rw,relatime)
    none on /sys type sysfs (rw,relatime)
    none on /dev/shm type tmpfs (rw,relatime)

    Directory /ansible inside the chroot is not writable but subdirectory
    /ansible/app is.

    Rest of the chroot is under overlay and all changes will be lost when
    chroot command ends. Only changes in app directory persists bacause it
    was bind mounted as read-write and is not part of overlay.

    Note: as you can see app directory is mounted over itself but read-write.
"
}

# layers are right to left! First is on the right, top/last is on the left
do_overlay_mount()
{
    # prepare dirs
mkdir -p $ovtempdir
mount -t tmpfs -o mode=0755 tmpfs $ovtempdir
    mkdir -p "$overlay"
    mkdir -p "$upperdir"
    mkdir -p "$workdir"

    # finally overlay mount
    if ! mount -t overlay \
        -o lowerdir="$lowerdir",upperdir="$upperdir",workdir="$workdir" \
        overlay "$overlay" ;
    then
        echo ERROR: "Failed to do overlay mount!" >&2
        echo ERROR: "Please check that your system supports overlay!" >&2
        echo NOTE: "Continuing with the ordinary chroot without overlay!"

        CHROOT_DIR="$lowerdir"
        return 1
    fi

    CHROOT_DIR="$overlay"

    return 0
}

check_external_mounts()
{
    echo "$EXTERNAL_MOUNTS" | while read -r mountexpr ; do
        #Skip empty lines, done with if for readability.
        if [ -z $mountexpr ]; then
            continue
        fi
        mount_type=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $1;}')
        external=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $2;}')
        internal=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $3;}')

        case "$mount_type" in
            ro|rw)
                :
                ;;
            *)
                echo ERROR: "Wrong mount type (should be 'ro' or 'rw') in: ${mountexpr}" >&2
                exit 1
                ;;
        esac

        # sanity check that the mountpoint is not empty or the root directory itself
        if echo "$internal" | grep -q '^/*$' ; then
            echo ERROR: "Unacceptable internal path: ${internal}" >&2
            exit 1
        fi
    done
}

do_external_mounts()
{
    echo INFO: "Bind mounting of external mounts..." >&2
    echo "$EXTERNAL_MOUNTS" | while read -r mountexpr ; do
        if [ -z $mountexpr ]; then
            continue
        fi
        mount_type=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $1;}')
        external=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $2;}')
        internal=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $3;}')

        # trying to follow the behaviour of docker
        if ! [ -e "$external" ] || [ -d "$external" ] ; then
            # external is a dir
            if ! mkdir -p "$external" ; then
                echo ERROR: "Cannot create directory: ${external}" >&2
                exit 1
            fi
            if ! mkdir -p "${CHROOT_DIR}/${internal}" ; then
                echo ERROR: "Cannot create mountpoint: ${CHROOT_DIR}/${internal}" >&2
                exit 1
            fi
        elif [ -f "$external" ] ; then
            # if external is a file mount it as a file
            if [ -e "${CHROOT_DIR}/${internal}" ] && ! [ -f "${CHROOT_DIR}/${internal}" ] ; then
                echo ERROR: "Mounting a file but the mountpoint is not a file: ${CHROOT_DIR}/${internal}" >&2
                exit 1
            else
                if ! touch "${CHROOT_DIR}/${internal}" ; then
                    echo ERROR: "Cannot create mountpoint: ${CHROOT_DIR}/${internal}" >&2
                    exit 1
                fi
            fi
        else
            # anything but a simple file or a directory will fail
            echo ERROR: "Unsupported mount: ${external} -> ${internal}" >&2
            exit 1
        fi

#Note, this double mounting is needed to support older util-linux.
        if ! mount -o bind "${external}" "${CHROOT_DIR}/${internal}" ||
          ! mount -o remount,bind,${mount_type} "${CHROOT_DIR}/${internal}" ; then
            echo ERROR: "Failed to mount: ${external} -> ${internal}" >&2
            exit 1
        else
            echo INFO: "Mount: ${external} -> ${internal}" >&2
        fi
    done
}



#
# parse arguments out of namespace.
#

if [ -z $IN_NAMESPACE ]; then
    export state=nil
    export action=nil
    export EXTERNAL_MOUNTS=''
    export CHROOT_WORKDIR=''
    export CHROOT_METADIR=''
    export CHROOT_DIR=''
    export COMMAND=''
    while [ -n "$1" ] ; do
        case "$state" in
            nil)
                case "$1" in
                    ''|-h|--help|help)
                        help
                        exit 0
                        ;;
                    --mount)
                        EXTERNAL_MOUNTS=$(printf "%s\n%s" "$EXTERNAL_MOUNTS" "${2}")
                        state=next
                        ;;
                    --workdir)
                        if [ -z "$CHROOT_WORKDIR" ] ; then
                            CHROOT_WORKDIR="$2"
                            state=next
                        else
                            echo ERROR: "Multiple working directory argument" >&2
                            help >&2
                            exit 1
                        fi
                        ;;
                    execute)
                        action=execute
                        state=execute
                        ;;
                    *)
                        echo ERROR: "Bad usage" >&2
                        help >&2
                        exit 1
                        ;;
                esac
                ;;
            next)
                state=nil
                ;;
            execute)
                CHROOT_METADIR="$1"
                shift
                break
                ;;
        esac
        shift
    done


    if [ $action = "nil" ]; then
        echo ERROR: "Nothing to do - missing command" >&2
        help >&2
        exit 1
    fi

    # do sanity checking ...

    if [ -z "$CHROOT_METADIR" ] ; then
        echo ERROR: "Missing argument" >&2
        help >&2
        exit 1
    fi

    # making sure that CHROOT_METADIR is absolute path
    CHROOT_METADIR=$(readlink -f "$CHROOT_METADIR")

    if ! [ -d "$CHROOT_METADIR"/chroot ] ; then
        echo ERROR: "Filepath does not exist: ${CHROOT_METADIR}/chroot" >&2
        exit 1
    fi

    # check external mounts if there are any
    check_external_mounts

    # we must be root
    if [ "$(id -u)" -ne 0 ] ; then
        echo ERROR: "Need to be root and you are not: $(id -nu)" >&2
        exit 1
    fi

    if ! which unshare >/dev/null 2>/dev/null ; then
        echo ERROR: "'unshare' system command is missing - ABORT" >&2
        echo INFO: "Try to install 'util-linux' package" >&2
        exit 1
    fi

    # ... sanity checking done

    #Reexec ourselves in new pid and mount namespace (isolate!).
    #Note: newly executed shell will be pid1 in a new namespace. Killing it will kill
    #every other process in the whole process tree with sigkill. That will in turn
    #destroy namespaces and undo all mounts done previously.
    IN_NAMESPACE=1 exec unshare -mpf "$0" "$@"
fi

#We are namespaced.
# setup paths
lowerdir="$CHROOT_METADIR"/chroot
ovtempdir="$CHROOT_METADIR"/tmp
upperdir="$ovtempdir"/.overlay
workdir="$ovtempdir"/.workdir
overlay="$CHROOT_METADIR"/.merged

#In case we are using a realy old unshare, make the whole tree into private mounts manually.
mount --make-rprivate /
#New mounts are private always from now on.

do_overlay_mount

# do the user-specific mounts
do_external_mounts

#And setup api filesystems.
mount -t proc proc "${CHROOT_DIR}/proc"
mount -t sysfs none "${CHROOT_DIR}/sys"
mount -t tmpfs none "${CHROOT_DIR}/dev"

mkdir -p "${CHROOT_DIR}/dev/shm"
mkdir -p "${CHROOT_DIR}/dev/pts"
mount -t devpts none "${CHROOT_DIR}/dev/pts"

mknod -m 666 "${CHROOT_DIR}/dev/full" c 1 7
mknod -m 666 "${CHROOT_DIR}/dev/ptmx" c 5 2
mknod -m 644 "${CHROOT_DIR}/dev/random" c 1 8
mknod -m 644 "${CHROOT_DIR}/dev/urandom" c 1 9
mknod -m 666 "${CHROOT_DIR}/dev/zero" c 1 5
mknod -m 666 "${CHROOT_DIR}/dev/tty" c 5 0
mknod -m 622 "${CHROOT_DIR}/dev/console" c 5 1
mknod -m 666 "${CHROOT_DIR}/dev/null" c 1 3
ln -s /proc/self/fd/0 "$CHROOT_DIR/dev/stdin"
ln -s /proc/self/fd/1 "$CHROOT_DIR/dev/stdout"
ln -s /proc/self/fd/2 "$CHROOT_DIR/dev/stderr"

# execute chroot
if [ -z "$1" ] ; then
    set -- /bin/sh -l
fi

#The redirection is to save our stdin, because we use it to pipe commands and we
#may want interactivity.
exec chroot "${CHROOT_DIR}" /bin/sh /dev/stdin "${CHROOT_WORKDIR:-/}" "$@" 3<&0 << "EOF"
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
mkdir -p $1
cd $1
shift
#I intend to reset stdin back *and* close the copy.
exec "$@" <&3 3<&-
EOF

exit 0

