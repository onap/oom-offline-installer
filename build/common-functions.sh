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

#
# this file contains shared variables and functions for the onap installer
#

# any script which needs this file can check this variable
# and it will know immediately if the functions and variables
# are loaded and usable
IS_COMMON_FUNCTIONS_SOURCED=YES

PATH="${PATH}:/usr/local/bin:/usr/local/sbin"
export PATH

# just self-defense against locale
LANG=C
export LANG

# default credentials to the repository
NEXUS_USERNAME=admin
NEXUS_PASSWORD=admin123
NEXUS_EMAIL=admin@onap.org

# this function is intended to unify the installer output
message() {
    case "$1" in
        info)
            echo 'INFO:' "$@"
            ;;
        debug)
            echo 'DEBUG:' "$@" >&2
            ;;
        warning)
            echo 'WARNING [!]:' "$@" >&2
            ;;
        error)
            echo 'ERROR [!!]:' "$@" >&2
            return 1
            ;;
        *)
            echo 'UNKNOWN [?!]:' "$@" >&2
            return 2
            ;;
    esac
    return 0
}
export message

# if the environment variable DEBUG is set to DEBUG-ONAP ->
#  -> this function will print its arguments
# otherwise nothing is done
debug() {
    [ "$DEBUG" = DEBUG-ONAP ] && message debug "$@"
}
export debug

fail() {
    message error "$@"
    exit 1
}

retry() {
    local n=1
    local max=5
    while ! "$@"; do
        if [ $n -lt $max ]; then
            n=$((n + 1))
            message warning "Command ${@} failed. Attempt: $n/$max"
            message info "waiting 10s for another try..."
            sleep 10s
        else
            fail "Command ${@} failed after $n attempts. Better to abort now."
        fi
    done
}

get_cfg_val() {
    name="$1"
    shift
    ask="$@"

    value=$(eval "echo \$${name}")
    if [ -z "$value" ]; then
        while [ -z "$value" ] ; do
            printf "${ask}"
            read -r $name

            value=$(eval "echo \$${name}")
        done
        echo "${name}='${value}'" >> ./local_repo.conf
    fi
}

get_configuration() {
    if [ -f ./local_repo.conf ]; then
        . ./local_repo.conf
    fi

    if [ -z "${NEXUS_FQDN}" ]; then
        NEXUS_FQDN="nexus.$HOSTNAME"
        echo "NEXUS_FQDN='${NEXUS_FQDN}'" >> ./local_repo.conf
    fi

    if [ -z "${ONAP_SCALE}" ]; then
        ONAP_SCALE=full
        echo "ONAP_SCALE='${ONAP_SCALE}'" >> ./local_repo.conf
    fi

    # nexus should be configured using those default entries
    # if it was not put the correct inputs instead
    if [ -z "${NPM_USERNAME}" ]; then
        NPM_USERNAME="${NEXUS_USERNAME}"
        echo "NPM_USERNAME='${NPM_USERNAME}'" >> ./local_repo.conf
    fi

    if [ -z "${NPM_PASSWORD}" ]; then
        NPM_PASSWORD="${NEXUS_PASSWORD}"
        echo "NPM_PASSWORD='${NPM_PASSWORD}'" >> ./local_repo.conf
    fi

    if [ -z "${NPM_EMAIL}" ]; then
        NPM_EMAIL="$NEXUS_EMAIL"
        echo "NPM_EMAIL='${NPM_EMAIL}'" >> ./local_repo.conf
    fi

    export NEXUS_FQDN
    export ONAP_SCALE
    export NPM_USERNAME
    export NPM_PASSWORD
    export NPM_EMAIL

    NODE_USERNAME="root"

    if [ -z "$LOCAL_IP" ] ; then
        echo
        echo "======= Mandatory configuration ======="
        echo
        message info "fill in these mandatory configuration values"
        get_cfg_val "LOCAL_IP" "Enter the public IPv4 used for this '$HOSTNAME' install machine," \
            "\nDO NOT USE LOOPBACK! (for example: 10.0.0.1): "
    fi
}

