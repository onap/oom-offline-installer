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

# setting of the path variables
if [ -z "$APROJECT_DIR" ] ; then
    INCLUDE_PATH="${LOCAL_PATH}"/"${RELATIVE_PATH}"
    APROJECT_DIR=$(readlink -f "$INCLUDE_PATH"/../..)
fi

RESOURCES_DIR="$APROJECT_DIR/resources"
BASH_SCRIPTS_DIR="$APROJECT_DIR/bash"
NEXUS_DATA="$RESOURCES_DIR/nexus_data"
CERTS_TARGET_PATH="$APROJECT_DIR/live/certs"
NGINX_LOG_DIR="$APROJECT_DIR/live/nginx_logs"
GEN_CFG_PATH="$APROJECT_DIR/live/cfg"
GIT_REPOS="$RESOURCES_DIR/git-repo"
NGINX_HTTP_DIR="$RESOURCES_DIR/http"
RHEL_REPO="$RESOURCES_DIR/pkg/rhel"

PATH="${PATH}:/usr/local/bin:/usr/local/sbin"
export PATH

# just self-defense against locale
LANG=C
export LANG

# dns handling
SIMUL_HOSTS="gcr.io \
git.rancher.io \
gerrit.onap.org \
registry-1.docker.io \
docker.io \
registry.npmjs.org \
nexus3.onap.org \
nexus.onap.org \
docker.elastic.co \
www.getcloudify.org \
www.springframework.org \
registry.hub.docker.com \
git.onap.org \
repo1.maven.org \
repo.maven.apache.org"

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

may_self_extract() {
    # extract and untar to the current directory
    sed '0,/^# PAYLOAD BELOW #$/d' "$0" | tar -xvpf - ;
}

update_hosts() {
    if grep -q "^[^#]\+\s$SIMUL_HOSTS\s*\$" /etc/hosts ; then
        message info "simulated domains already in /etc/hosts"
    else
        echo "$LOCAL_IP $SIMUL_HOSTS" >> /etc/hosts
        message info "simulated domains added to /etc/hosts (please check it)"
    fi

    if grep -q "^[^#]\+\s$NEXUS_FQDN\s*\$" /etc/hosts ; then
        message info "nexus FQDN already in /etc/hosts"
    else
        echo "$LOCAL_IP $NEXUS_FQDN" >> /etc/hosts
        message info "Nexus FQDN added to /etc/hosts (please check it)"
    fi

    if grep -q "^[^#]\+\srepo.install-server\s*\$" /etc/hosts ; then
        message info "custom repo FQDN already in /etc/hosts"
    else
        echo "$LOCAL_IP repo.install-server" >> /etc/hosts
        message info "Nexus FQDN added to /etc/hosts (please check it)"
    fi
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

enable_local_repo() {
    sed -r "s%PATH%file://$APROJECT_DIR/resources/pkg/rhel%" "$APROJECT_DIR/resources/pkg/rhel/onap.repo" > /etc/yum.repos.d/onap.repo
}

install_packages() {
    os_id="$1"

    message info "Installing packages"

    case "$os_id" in
        centos)
            yum -y install "$APROJECT_DIR/resources/pkg/centos/*.rpm"
            ;;
        rhel)
            enable_local_repo
            yum -y install docker-ce dnsmasq icewm firefox tigervnc-server
            systemctl enable docker
            systemctl start docker
            ;;
        ubuntu)
            dpkg -i "$APROJECT_DIR/resources/pkg/ubuntu/*.deb"
            ;;
        *)
            message error "OS release is not supported: $os_id"
            message info "ABORTING INSTALLATION"
            exit 1
            ;;
    esac
}

install_files() {
    message info "installation of external binaries"
    for binary in kubectl helm rancher jq ; do
        cp "$APROJECT_DIR/resources/downloads/${binary}" /usr/local/bin/
        chmod 755 "/usr/local/bin/${binary}"
    done
    mkdir ~/.kube
}

setup_vnc_server() {
    mkdir -p ~/.vnc ~/.icewm
    echo "onap" | vncpasswd -f > ~/.vnc/passwd
    chmod 0600 ~/.vnc/passwd

    cat > ~/.vnc/xstartup <<EOF
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec icewm-session

EOF

chmod +x ~/.vnc/xstartup

    cat > ~/.icewm/menu <<EOF
prog Firefox firefox firefox
separator

EOF
vncserver
}

update_docker_cfg() {
    if [ -f "/etc/docker/daemon.json" ]; then
        jq '.dns += ["172.17.0.1"]' /etc/docker/daemon.json > /tmp/daemon.json
        mv /tmp/daemon.json /etc/docker/daemon.json
    else
        echo '{"dns": ["172.17.0.1"]}' > /etc/docker/daemon.json
    fi
}

create_root_CA() {
    echo "** Generate certificates **"
    openssl genrsa -out $CERTS_TARGET_PATH/rootCA.key 4096

    echo "** Generate self signed ***"
    openssl req -config $GEN_CFG_PATH/cacert.cnf -key $CERTS_TARGET_PATH/rootCA.key -new -x509 -days 7300 -sha256 -extensions v3_ca \
                  -out $CERTS_TARGET_PATH/rootCAcert.pem


    # convert to crt
    openssl x509 -in $CERTS_TARGET_PATH/rootCAcert.pem -inform PEM -out $CERTS_TARGET_PATH/rootCAcert.crt
}

install_root_CA() {
    os=$1
    echo "** Publishing root CA **"
    if [ "$os" == "redhat" ]; then
        # for centos
        update-ca-trust force-enable
        cp $CERTS_TARGET_PATH/rootCAcert.crt /etc/pki/ca-trust/source/anchors/
        update-ca-trust extract
    elif [ "$os" == "ubuntu" ]; then
        mkdir -p /usr/local/share/ca-certificates/extra
        cp $CERTS_TARGET_PATH/rootCAcert.crt /usr/local/share/ca-certificates/extra
        update-ca-certificates
    else
        echo "OS \"$os\" is not supported"
        exit -2
    fi

    echo "** Restart docker (because of reload new CA) **"
    systemctl restart docker

}

create_cert() {
    server_name=$1

    openssl genrsa -out $CERTS_TARGET_PATH/${server_name}_server.key 4096
    echo "** Generate sig request ***"
    openssl req -new -config $GEN_CFG_PATH/${server_name}_cert.cnf -key $CERTS_TARGET_PATH/${server_name}_server.key -out $CERTS_TARGET_PATH/${server_name}_server.csr

    # v3.ext must be in separate file , because of bug in openssl 1.0
    echo "** sign **"
    openssl x509 -req -in $CERTS_TARGET_PATH/${server_name}_server.csr\
    -extfile $GEN_CFG_PATH/v3.ext\
    -CA $CERTS_TARGET_PATH/rootCAcert.crt\
    -CAkey $CERTS_TARGET_PATH/rootCA.key\
    -CAcreateserial -out $CERTS_TARGET_PATH/${server_name}_server.crt -days 3650 -sha256
}

create_all_certs() {
    create_cert "nexus"
}

update_firewall() {
# TODO
#firewall-cmd --permanent --add-port=53/udp
#firewall-cmd --permanent --add-port=53/tcp
#firewall-cmd --permanent --add-port=10001/tcp
#firewall-cmd --permanent --add-port=80/tcp
#firewall-cmd --permanent --add-port=443/tcp
return 0
}

distribute_root_CA() {
    targetip=$1
    scp $APROJECT_DIR/install_cacert.sh $targetip:.
    ssh $targetip ./install_cacert.sh
    echo "** Add DNS record to remote host **"
    ssh $targetip "echo nameserver $LOCAL_IP > /etc/resolv.conf"
}

upload_ansible_pkgs() {
    os=$1
    targetip=$2
    #if [[ $os == "ubuntu" ]]; then
    # those deb & whl packages are needed for sdnc-ansible-server pod
    # independently on host OS distros
    echo "** Copy required packages for sdnc-ansible-pod to kubernetes node $targetip **"
    scp -r $APROJECT_DIR/resources/pkg/ubuntu/ansible_pkg $targetip:.
    #fi
}

remote_setup_nfs_server() {
    os=$1
    targetip=$2
    shift 2
    scp $APROJECT_DIR/bash/tools/setup_nfs_server_${os}.sh $targetip:setup_nfs_server.sh
    if [[ $os == "ubuntu" ]]; then
        scp -r $APROJECT_DIR/resources/pkg/ubuntu/nfs-common-pkg/* $targetip:.
        ssh $targetip dpkg -i *.deb
    fi

    ssh $targetip /bin/bash ./setup_nfs_server.sh "$@"
}

remote_setup_nfs_mount() {
    os=$1
    targetip=$2
    nfsip=$3
    scp $APROJECT_DIR/bash/tools/setup_nfs_mount.sh $targetip:.
    if [[ $os == "ubuntu" ]]; then
        scp -r $APROJECT_DIR/resources/pkg/ubuntu/nfs-common-pkg/* $targetip:.
        ssh $targetip dpkg -i *.deb
    fi
    ssh $targetip /bin/bash ./setup_nfs_mount.sh $nfsip
}

enable_remote_repo() {
    targetip=$1
    sed -r "s%PATH%http://repo.install-server%" $APROJECT_DIR/resources/pkg/rhel/onap.repo | ssh $targetip 'cat > /etc/yum.repos.d/onap.repo'
}

install_remote_docker() {
    targetip=$1
    os=$2
    if [[ $os == "ubuntu" ]]; then
        scp -r $APROJECT_DIR/resources/pkg/ubuntu/{docker-ce_17.03.2~ce-0~ubuntu-xenial_amd64.deb,libltdl7_2.4.6-0.1_amd64.deb} $targetip:.
        ssh $targetip dpkg -i *.deb
    elif [[ $os == "rhel" ]]; then
        ssh $targetip yum -y install docker-ce
    fi
    ssh $targetip "mkdir -p /etc/docker"
    scp "$APROJECT_DIR/resources/downloads/jq" $targetip:/usr/local/bin/
    ssh $targetip "if [[ -f /etc/docker/daemon.json ]]; then
                       jq '.dns += [\"$LOCAL_IP\"]' /etc/docker/daemon.json > /tmp/daemon.json
                       mv /tmp/daemon.json /etc/docker/daemon.json
                   else
                       echo {'\"'dns'\"': ['\"'$LOCAL_IP'\"']} > /etc/docker/daemon.json
                   fi"

    ssh $targetip 'systemctl enable docker; systemctl restart docker'
}

deploy_rancher() {
    docker run -d --entrypoint "/bin/bash" --restart=unless-stopped -p 8080:8080 \
    -v $CERTS_TARGET_PATH:/usr/local/share/ca-certificates/extra:ro \
    --name rancher_server rancher/server:v1.6.14 \
    -c "/usr/sbin/update-ca-certificates;/usr/bin/entry /usr/bin/s6-svscan /service"
    echo "** wait until rancher is ready **"
}

deploy_kubernetes() {
    os=$1
    set +e
    for i in `seq 5 -1 1`; do
        API_RESPONSE=`curl -s 'http://127.0.0.1:8080/v2-beta/apikey' \
            -d '{"type":"apikey","accountId":"1a1","name":"autoinstall"\
                 ,"description":"autoinstall","created":null,"kind":null,\
                 "removeTime":null,"removed":null,"uuid":null}'`
        if [[ "$?" -eq 0 ]]; then
            KEY_PUBLIC=`echo $API_RESPONSE | jq -r .publicValue`
            KEY_SECRET=`echo $API_RESPONSE | jq -r .secretValue`
            break
        fi
        echo "Waiting for rancher server to start"
        sleep 60
    done
    set -e
    export RANCHER_URL=http://${LOCAL_IP}:8080
    export RANCHER_ACCESS_KEY=$KEY_PUBLIC
    export RANCHER_SECRET_KEY=$KEY_SECRET

    rancher env ls
    echo "wait 60 sec for rancher environments can settle before we create the onap kubernetes one"
    sleep 60

    rancher env create -t kubernetes onap > kube_env_id.json
    PROJECT_ID=$(<kube_env_id.json)
    echo "env id: $PROJECT_ID"
    export RANCHER_HOST_URL=http://${LOCAL_IP}:8080/v1/projects/$PROJECT_ID

    for i in `seq 5`; do
        status=$(rancher env ls | grep $PROJECT_ID | awk '{print $4}')
        if [[ "$status" == "active" ]]; then
            echo "Check on environments again before registering the URL response"
            rancher env ls
            break
        fi
        echo "Wait for environment to become active"
        sleep 30
    done

    REG_URL_RESPONSE=`curl -X POST -u $KEY_PUBLIC:$KEY_SECRET -H 'Accept: application/json' -H 'ContentType: application/json' -d '{"name":"$LOCAL_IP"}' "http://$LOCAL_IP:8080/v1/projects/$PROJECT_ID/registrationtokens"`
    echo "wait for server to finish url configuration - 3 min"
    sleep 180
    # see registrationUrl in
    REGISTRATION_TOKENS=`curl http://127.0.0.1:8080/v2-beta/registrationtokens`
    REGISTRATION_DOCKER=`echo $REGISTRATION_TOKENS | jq -r .data[0].image`
    REGISTRATION_TOKEN=`echo $REGISTRATION_TOKENS | jq -r .data[0].token`

    # base64 encode the kubectl token from the auth pair
    # generate this after the host is registered
    KUBECTL_TOKEN=$(echo -n 'Basic '$(echo -n "$RANCHER_ACCESS_KEY:$RANCHER_SECRET_KEY" | base64 -w 0) | base64 -w 0)
    echo "KUBECTL_TOKEN base64 encoded: ${KUBECTL_TOKEN}"
    cat > ~/.kube/config <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    insecure-skip-tls-verify: true
    server: "https://$LOCAL_IP:8080/r/projects/$PROJECT_ID/kubernetes:6443"
  name: "onap"
contexts:
- context:
    cluster: "onap"
    user: "onap"
  name: "onap"
current-context: "onap"
users:
- name: "onap"
  user:
    token: "$KUBECTL_TOKEN"

EOF

    if [[ $os == "rhel" ]]; then
        echo "Upgrade datavolume for RHEL"
        KUBELET_ID=`curl http://${LOCAL_IP}:8080/v2-beta/projects/${PROJECT_ID}/services/ | jq -r '.data[] | select(.name=="kubelet")'.id`
        OLD_LAUNCH_CONFIG=`curl http://${LOCAL_IP}:8080/v2-beta/projects/${PROJECT_ID}/services/${KUBELET_ID} | jq  '.launchConfig'`
        NEW_LAUNCH_CONFIG=`echo $OLD_LAUNCH_CONFIG | jq '.dataVolumes[2]="/sys/fs/cgroup:/sys/fs/cgroup:ro,rprivate"'`

        DATA="{
                \"inServiceStrategy\": {
                  \"batchSize\": 1,
                  \"intervalMillis\": 2000,
                  \"startFirst\": false,
                  \"launchConfig\": ${NEW_LAUNCH_CONFIG},
                  \"secondaryLaunchConfigs\": []
                }
        }"
        curl -s -u $KEY_PUBLIC:$KEY_SECRET -X POST -H 'Content-Type: application/json' -d "${DATA}" "http://${LOCAL_IP}:8080/v2-beta/projects/${PROJECT_ID}/services/${KUBELET_ID}?action=upgrade" > /dev/null

        echo "Give environment time to update (30 sec)"
        sleep 30

        curl -s -u $KEY_PUBLIC:$KEY_SECRET -X POST "http://${LOCAL_IP}:8080/v2-beta/projects/${PROJECT_ID}/services/${KUBELET_ID}?action=finishupgrade" > /dev/null
    fi
}

deploy_rancher_agent() {
    nodeip=$1
    if [ -z "$REGISTRATION_DOCKER" ]; then
        echo "ASSERT: Missing REGISTRATION_DOCKER"
        exit 1
    fi
    if [ -z "$RANCHER_URL" ]; then
        echo "ASSERT: Missing RANCHER_URL"
        exit 1
    fi
    if [ -z "$REGISTRATION_TOKEN" ]; then
        echo "ASSERT: Missing REGISTRATION_TOKEN"
        exit 1
    fi

    ssh $nodeip "docker run --rm --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/racher:/var/lib/rancher $REGISTRATION_DOCKER $RANCHER_URL/v1/scripts/$REGISTRATION_TOKEN"
    echo "waiting 2 min for creating kubernetes environment"
    sleep 120
}

deploy_node() {
    nodeip=$1
    os=$2
    echo "Deploying node $nodeip"
    distribute_root_CA $nodeip
    install_remote_docker $nodeip $os
    deploy_rancher_agent $nodeip
}

deploy_onap() {
    pushd $APROJECT_DIR/resources/oom/kubernetes
    helm init --upgrade --skip-refresh
    # this might fail
    set +e
    helm repo remove stable
    set -e
    helm serve &
    echo "wait a moment before helm will come up ..."
    sleep 5
    helm repo add local http://127.0.0.1:8879
    make all
    #Pass the CA certificate contents directly during installation.
    helm install local/onap -n dev --namespace onap \
      --set "global.cacert=$(cat ${CERTS_TARGET_PATH}/rootCAcert.crt)"
    popd
}

expand_file() {
    file=$1
    # print warning if patched file does not exist as some charts
    # might not be available for some deployments
    if [ ! -f "$file" ]; then
      echo "WARNING: Can't patch file $file because this file does not exists."
      return 0
    fi

    shift

    for ivar in "$@" ; do
        ivalue=$(eval 'echo "$'${ivar}'"')
        sed -i "s#${ivar}#${ivalue}#g" "$file"
    done
}

patch_npm_oom() {
    if [ -z "$LOCAL_IP" ] ; then
        echo "ERROR: LOCAL_IP unset"
        return 1
    fi
    if [ -z "$NEXUS_FQDN" ] ; then
        echo "ERROR: NEXUS_FQDN unset"
        return 1
    fi

    UPDATE_HOSTS_FILE="$LOCAL_IP $NEXUS_FQDN"
    UPDATE_NPM_REGISTRY="npm set registry \"http://${NEXUS_FQDN}/repository/npm-private/\""

    expand_file $APROJECT_DIR/resources/oom/kubernetes/common/dgbuilder/templates/deployment.yaml \
        UPDATE_HOSTS_FILE \
        UPDATE_NPM_REGISTRY
    expand_file $APROJECT_DIR/resources/oom/kubernetes/sdnc/charts/sdnc-portal/templates/deployment.yaml \
        UPDATE_HOSTS_FILE \
        UPDATE_NPM_REGISTRY
}

patch_spring_oom() {
    if [ -z "$LOCAL_IP" ] ; then
        echo "ERROR: LOCAL_IP unset"
        return 1
    fi

    UPDATE_HOSTS_FILE="$LOCAL_IP www.springframework.org"
    expand_file $APROJECT_DIR/resources/oom/kubernetes/dmaap/charts/message-router/templates/deployment.yaml \
        UPDATE_HOSTS_FILE
}

patch_cfy_manager_depl() {
    os="$1"
    file="${APROJECT_DIR}/resources/oom/kubernetes/dcaegen2/charts/dcae-cloudify-manager/templates/deployment.yaml"

    case "$os" in
        centos|rhel)
            CERT_PATH="/etc/pki/ca-trust/source/anchors"
            ;;
        ubuntu)
            CERT_PATH="/usr/local/share/ca-certificates/extra"
            ;;
        '')
            echo "ERROR: missing argument"
            return 1
            ;;
        *)
            echo "ERROR: unknown OS: ${os}"
            return 1
            ;;
    esac

    expand_file "$file" CERT_PATH
}

copy_onap_values_file() {
    cp "${APROJECT_DIR}/${CUSTOM_CFG_RELPATH:-cfg}/${ONAP_SCALE}_depl_values.yaml" \
        "${APROJECT_DIR}/resources/oom/kubernetes/onap/values.yaml"
}
