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
UMOUNT_TIMEOUT=120 # 2mins


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
                --mount ro:/scripts/ANSIBLE_DIR:/deploy \
                --mount rw:/scripts/ANSIBLE_DIR/app:/deploy/app
                This will mount directory deploy as read-only into chroot,
                but it's subdirectory 'app' will be writeable.

        --workdir <inner-dir>
            This will set working directory (PWD) inside the chroot.

EXAMPLE:
    ${CMD} --mount ro:/scripts/deploy:deploy \
        --mount rw:/scripts/deploy/app:deploy/app \
        --workdir /deploy execute /tmp/ansible_chroot
    # pwd
    /deploy
    # mount
    overlay on / type overlay ...
    /dev/disk on /deploy type ext4 (ro,relatime,errors=remount-ro)
    /dev/disk on /deploy/application type ext4 (rw,relatime,errors=remount-ro)
    none on /proc type proc (rw,relatime)
    none on /sys type sysfs (rw,relatime)
    none on /dev/shm type tmpfs (rw,relatime)

    Directory /deploy inside the chroot is not writable but subdirectory
    /deploy/app is.

    Rest of the chroot is under overlay and all changes will be lost when
    chroot command ends. Only changes in app directory persists bacause it
    was bind mounted as read-write and is not part of overlay.

    Note: as you can see app directory is mounted over itself but read-write.
"
}

# arg: <directory>
is_mounted()
{
    mountpoint=$(echo "$1" | sed 's#//*#/#g')

    LANG=C mount | grep -q "^[^[:space:]]\+[[:space:]]\+on[[:space:]]\+${mountpoint}[[:space:]]\+type[[:space:]]\+"
}

# layers are right to left! First is on the right, top/last is on the left
do_overlay_mount()
{
    if [ -d "$overlay" ] && is_mounted "$overlay" ; then
        echo ERROR: "The overlay directory is already mounted: $overlay" >&2
        echo ERROR: "Fix the issue - cannot proceed" >&2
        exit 1
    fi

    # prepare dirs
    rm -rf "$overlay" "$upperdir" "$workdir"
    mkdir -p "$overlay"
    mkdir -p "$upperdir"
    mkdir -p "$workdir"

    # finally overlay mount
    if ! mount -t overlay --make-rprivate \
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

cleanup()
{
    case "$OVERLAY_MOUNT" in
        yes)
            echo INFO: "Umounting overlay..." >&2
            if ! umount_retry "$CHROOT_DIR" ; then
                echo ERROR: "Cannot umount chroot: $CHROOT_DIR" >&2
                return 1
            fi

            ;;
        no)
            echo INFO: "No overlay to umount" >&2
            ;;
    esac

    if ! is_mounted "$overlay" ; then
        echo INFO: "Deleting of temp directories..." >&2
        rm -rf "$overlay" "$upperdir" "$workdir"
    else
        echo ERROR: "Overlay is still mounted: $CHROOT_DIR" >&2
        echo ERROR: "Cannot delete: $overlay" >&2
        echo ERROR: "Cannot delete: $upperdir" >&2
        echo ERROR: "Cannot delete: $workdir" >&2
        return 1
    fi
}

check_external_mounts()
{
    echo "$EXTERNAL_MOUNTS" | sed '/^[[:space:]]*$/d' | while read -r mountexpr ; do
        mount_type=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $1;}')
        external=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $2;}')
        internal=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $3;}' | sed -e 's#^/*##' -e 's#//*#/#g')

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
    echo "$EXTERNAL_MOUNTS" | sed '/^[[:space:]]*$/d' | while read -r mountexpr ; do
        mount_type=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $1;}')
        external=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $2;}')
        internal=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $3;}' | sed -e 's#^/*##' -e 's#//*#/#g')

        if is_mounted "${CHROOT_DIR}/${internal}" ; then
            echo ERROR: "Mountpoint is already mounted: ${CHROOT_DIR}/${internal}" >&2
            echo ERROR: "Fix the issue - cannot proceed" >&2
            exit 1
        fi

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

        if ! mount --make-rprivate -o bind,${mount_type} "$external" "${CHROOT_DIR}/${internal}" ; then
            echo ERROR: "Failed to mount: ${external} -> ${internal}" >&2
            exit 1
        else
            echo INFO: "Mount: ${external} -> ${internal}" >&2
        fi
    done
}

# arg: <mountpoint>
umount_retry()
{
    mountpoint=$(echo "$1" | sed 's#//*#/#g')
    timeout=${UMOUNT_TIMEOUT}

    umount "$mountpoint" 2>/dev/null
    while is_mounted "$mountpoint" && [ $timeout -gt 0 ] ; do
        umount "$mountpoint" 2>/dev/null
        sleep 1
        timeout=$(( timeout - 1 ))
    done

    if ! is_mounted "$mountpoint" ; then
        return 0
    fi

    return 1
}

undo_external_mounts()
{
    echo INFO: "Umount external mount points..." >&2
    echo "$EXTERNAL_MOUNTS" | tac | sed '/^[[:space:]]*$/d' | while read -r mountexpr ; do
        mount_type=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $1;}')
        external=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $2;}')
        internal=$(echo "$mountexpr" | awk 'BEGIN{FS=":"}{print $3;}' | sed -e 's#^/*##' -e 's#//*#/#g')
        if umount_retry "${CHROOT_DIR}/${internal}" ; then
            echo INFO: "Unmounted: ${CHROOT_DIR}/${internal}" >&2
        else
            echo ERROR: "Failed to umount: ${CHROOT_DIR}/${internal}" >&2
        fi
    done
}

install_wrapper()
{
    cat > "$CHROOT_DIR"/usr/local/bin/fakeshell.sh <<EOF
#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

gid_tty=\$(getent group | sed -n '/^tty:/p' | cut -d: -f 3)

mount -t proc proc /proc
mount -t sysfs none /sys
mount -t tmpfs none /dev

mkdir -p /dev/shm
mkdir -p /dev/pts
mount -t devpts -o gid=\${gid_tty},mode=620 none /dev/pts

[ -e /dev/full ] || mknod -m 666 /dev/full c 1 7
[ -e /dev/ptmx ] || mknod -m 666 /dev/ptmx c 5 2
[ -e /dev/random ] || mknod -m 644 /dev/random c 1 8
[ -e /dev/urandom ] || mknod -m 644 /dev/urandom c 1 9
[ -e /dev/zero ] || mknod -m 666 /dev/zero c 1 5
[ -e /dev/tty ] || mknod -m 666 /dev/tty c 5 0
[ -e /dev/console ] || mknod -m 622 /dev/console c 5 1
[ -e /dev/null ] || mknod -m 666 /dev/null c 1 3

chown root:tty /dev/console
chown root:tty /dev/ptmx
chown root:tty /dev/tty

mkdir -p "\$1" || exit 1
cd "\$1" || exit 1
shift

exec "\$@"

EOF
    chmod +x "$CHROOT_DIR"/usr/local/bin/fakeshell.sh
}

on_exit()
{
    set +e
    echo

    if [ -n "$OVERLAY_MOUNT" ] ; then
        undo_external_mounts
    fi
    cleanup
}


#
# parse arguments
#

state=nil
action=nil
EXTERNAL_MOUNTS=''
CHROOT_WORKDIR=''
CHROOT_METADIR=''
CHROOT_DIR=''
COMMAND=''
while [ -n "$1" ] ; do
    case "$state" in
        nil)
            case "$1" in
                ''|-h|--help|help)
                    help
                    exit 0
                    ;;
                --mount)
                    EXTERNAL_MOUNTS=$(printf "%s\n%s\n" "$EXTERNAL_MOUNTS" "${2}")
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


case "$action" in
    ''|nil)
        echo ERROR: "Nothing to do - missing command" >&2
        help >&2
        exit 1
        ;;
    execute)
        # firstly do sanity checking ...

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

        # check workdir
        if [ -n "$CHROOT_WORKDIR" ] ; then
            CHROOT_WORKDIR=$(echo "$CHROOT_WORKDIR" | sed -e 's#^/*##' -e 's#//*#/#g')
        fi

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

        # setup paths
        lowerdir="$CHROOT_METADIR"/chroot
        upperdir="$CHROOT_METADIR"/.overlay
        workdir="$CHROOT_METADIR"/.workdir
        overlay="$CHROOT_METADIR"/.merged

        # set trap
        trap on_exit QUIT TERM EXIT

        # mount overlay
        OVERLAY_MOUNT=''
        if do_overlay_mount ; then
            # overlay chroot
            OVERLAY_MOUNT=yes
        else
            # non overlay mount
            OVERLAY_MOUNT=no
        fi

        # do the user-specific mounts
        do_external_mounts

        # I need this wrapper to do some setup inside the chroot...
        install_wrapper

        # execute chroot
        if [ -n "$1" ] ; then
            :
        else
            set -- /bin/sh -l
        fi
        unshare -mfpi --propagation private \
            chroot "$CHROOT_DIR" /usr/local/bin/fakeshell.sh "${CHROOT_WORKDIR:-/}" "$@"
        ;;
esac

exit 0

