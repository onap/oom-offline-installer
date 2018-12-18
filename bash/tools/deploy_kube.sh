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

# OS check
. /etc/os-release
OS_ID="${ID}"

case "$OS_ID" in
    centos)
        ;;
    rhel)
        ;;
    ubuntu)
        ;;
    *)
        echo This OS is not supported: $OS_ID
        exit 1
        ;;
esac

# boilerplate
RELATIVE_PATH=./ # relative path from this script to 'common-functions.sh'
if [ "$IS_COMMON_FUNCTIONS_SOURCED" != YES ] ; then
    SCRIPT_DIR=$(dirname "${0}")
    LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")
    . "${LOCAL_PATH}"/"${RELATIVE_PATH}"/common-functions.sh
fi

message info "Reading configuration"
get_configuration
if [ -z "$NODES_IPS" ] ; then
    get_cfg_val "NODES_IPS" "Enter the public IPv4 addresses of kubernetes nodes separated by space," \
    "\n(for example: 10.0.0.2 10.0.0.3 ...): "
fi

echo "Wait for nexus startup (1min)"
sleep 60


# on install server
deploy_rancher
deploy_kubernetes "$OS_ID"

echo "Setting up ONAP Local Repo on Kubernetes nodes"
for node in ${NODES_IPS} ; do
    enable_remote_repo $node
done

# setup NFS on nodes
assort_nodes_ips() {
    nfs_server="$1"
    shift
    nfs_clients="$*"
}
assort_nodes_ips ${NODES_IPS}
if [ -n "${nfs_clients}" ]; then
    echo "Setting up NFS"
    remote_setup_nfs_server $OS_ID ${nfs_server} ${nfs_clients}
    for node in ${nfs_clients} ; do
        remote_setup_nfs_mount $OS_ID $node ${nfs_server}
    done
else
    echo "Only one node set. Skipping nfs configuration"
fi

echo "Copy ansible packages for onap ansible-server"
for node in ${NODES_IPS} ; do
    upload_ansible_pkgs $OS_ID $node
done

# to nodes
for node in ${NODES_IPS} ; do
    deploy_node $node $OS_ID
done
