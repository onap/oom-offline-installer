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

#
# local functions
#

start_nexus() {
    echo "** Starting nexus **"
    if [[ -z "$NEXUS_DATA" ]]; then
        echo "Nexus data env is not set"
        exit -3
    fi

    # valid for case of fresh nexus deployment
    # data are inserted in later phases
    mkdir -p $NEXUS_DATA
    # hardening
    chmod a+wrX $NEXUS_DATA
    chown -R 200:200 $NEXUS_DATA

    docker rm -f nexus 1> /dev/null 2>&1 || true

    docker run -d --name nexus\
        --restart unless-stopped \
        -v $NEXUS_DATA:/nexus-data:rw \
        sonatype/nexus3

    echo "** Creating docker network **"
    docker network create nexus_network
    docker network connect nexus_network nexus
}

start_nginx() {
    echo "** Starting reverse proxy - nginx **"

    docker rm -f nginx 1> /dev/null 2>&1 || true
    mkdir -p $NGINX_HTTP_DIR/repo.install-server

    mkdir -p "$NGINX_HTTP_DIR/repo.install-server"

    docker run -d -p 80:80 -p 443:443 -p 10001:443 \
        --name nginx \
        --network nexus_network \
        -v $GEN_CFG_PATH/nginx.conf:/etc/nginx/nginx.conf:ro \
        -v $CERTS_TARGET_PATH:/etc/nginx/certs:ro \
        -v $GIT_REPOS:/srv/git:rw \
        -v $NGINX_LOG_DIR:/var/log/nginx:rw \
        -v $NGINX_HTTP_DIR:/srv/http:ro \
        -v $RHEL_REPO:/srv/http/repo.install-server:ro \
        --restart unless-stopped \
        own_nginx
}

patch_cert() {
    file=$1
    cp "$APROJECT_DIR/cfg/$file" "$GEN_CFG_PATH/$file"
#    sed "s#countryName =.*#countryName = $CERT_COUNTRY#" "$APROJECT_DIR/cfg/$file" > $GEN_CFG_PATH/$file
#    sed "s#localityName =.*#localityName = $CERT_LOCALITY#" "$APROJECT_DIR/cfg/$file" > $GEN_CFG_PATH/$file
#    sed "s#organizationName =.*#organizationName = $CERT_ORGANIZATION#" "$APROJECT_DIR/cfg/$file" > $GEN_CFG_PATH/$file
}

patch_conf_files() {
    # patch nexus and root cert
    patch_cert nexus_cert.cnf
    patch_cert cacert.cnf

    # patch nexus v3 ext cert
    sed "s#nexus.student12#$NEXUS_FQDN#" "$APROJECT_DIR/cfg/v3.ext" > $GEN_CFG_PATH/v3.ext

    #patch nginx.conf
    sed "s#nexus.student12#$NEXUS_FQDN#" "$APROJECT_DIR/cfg/nginx.conf" > $GEN_CFG_PATH/nginx.conf
}

#
# body
#

message info "Nexus will be installed into this directory: $(pwd)"

if ! [ -f ./local_repo.conf ]; then
    printf "[?] > Do you want continue? (if no, hit CTRL+C): "
    read x
fi

message info "Reading configuration"
get_configuration

mkdir -p "$CERTS_TARGET_PATH"
mkdir -p "$NGINX_LOG_DIR"
mkdir -p "$GEN_CFG_PATH"
if [ "$IS_SELF_EXTRACT" = YES ] ; then
    message info "Now I will untar the resources"
    message info "This may take a long time..."
    sleep 3s
    may_self_extract
fi

#
echo "Cleanup docker (if installed)"
docker rm -f nginx 1> /dev/null 2>&1 || true
docker rm -f nexus 1> /dev/null 2>&1 || true

install_files
install_packages "$OS_ID"
setup_vnc_server

update_hosts

# TODO
#check_dependencies

echo "Restarting dnsmasq"
# TODO dnsmasq config?
systemctl enable dnsmasq
systemctl restart dnsmasq

echo "** Generating config files to $GEN_CFG_PATH **"
echo "Configure ssl certificates"

patch_conf_files
create_root_CA

# create selfinstall CA cert
$BASH_SCRIPTS_DIR/tools/create_si_cacert_pkg.sh
# run generated file
./install_cacert.sh

create_cert "nexus"

echo "** Certificates finished **"

update_docker_cfg

echo "Restarting docker"
systemctl enable docker
systemctl restart docker

update_firewall

set +e

echo "** Loading images **"
docker load -i $RESOURCES_DIR/offline_data/docker_images_infra/sonatype_nexus3_latest.tar
docker load -i $RESOURCES_DIR/offline_data/docker_images_infra/own_nginx_latest.tar

start_nexus
start_nginx
