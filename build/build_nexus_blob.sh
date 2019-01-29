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


### This script prepares Nexus repositories data blobs for ONAP

# Mandatory variables need to be set in configuration file:
#   NXS_SRC_DOCKER_IMG_DIR  - resource directory of docker images
#   NXS_SRC_NPM_DIR         - resource directory of npm packages
#   NXS_DOCKER_IMG_LIST     - list of docker images to be pushed to Nexus repository
#   NXS_DOCKER_WO_LIST      - list of docker images which uses default repository
#   NXS_NPM_LIST            - list of npm packages to be published to Nexus repository
#   NEXUS_DATA_TAR          - target tarball of Nexus data path/name
#   NEXUS_DATA_DIR          - directory used for the Nexus blob build
#   NEXUS_IMAGE             - Sonatype/Nexus3 docker image which will be used for data blob creation

# Fail fast settings
set -e

# Nexus repository location
NEXUS_DOMAIN="nexus"
NPM_REGISTRY="http://${NEXUS_DOMAIN}:8081/repository/npm-private/"
DOCKER_REGISTRY="${NEXUS_DOMAIN}:8082"

# Nexus repository credentials
NEXUS_USERNAME=admin
NEXUS_PASSWORD=admin123
NEXUS_EMAIL=admin@example.org

# Setup simulated domain names to be able to push all in private Nexus repository
SIMUL_HOSTS="docker.elastic.co gcr.io hub.docker.com nexus3.onap.org nexus.onap.org registry.hub.docker.com ${NEXUS_DOMAIN}"

# Nexus repository configuration setup
NEXUS_CONFIG_GROOVY='import org.sonatype.nexus.security.realm.RealmManager
import org.sonatype.nexus.repository.attributes.AttributesFacet
import org.sonatype.nexus.security.user.UserManager
import org.sonatype.nexus.repository.manager.RepositoryManager
import org.sonatype.nexus.security.user.UserNotFoundException
/* Use the container to look up some services. */
realmManager = container.lookup(RealmManager.class)
userManager = container.lookup(UserManager.class, "default") //default user manager
repositoryManager = container.lookup(RepositoryManager.class)
/* Managers are used when scripting api cannot. Note that scripting api can only create mostly, and that creation methods return objects of created entities. */
/* Perform cleanup by removing all repos and users. Realms do not need to be re-disabled, admin and anonymous user will not be removed. */
userManager.listUserIds().each({ id ->
    if (id != "anonymous" && id != "admin")
        userManager.deleteUser(id)
})
repositoryManager.browse().each {
    repositoryManager.delete(it.getName())
}
/* Add bearer token realms at the end of realm lists... */
realmManager.enableRealm("NpmToken")
realmManager.enableRealm("DockerToken")
/* Create the docker user. */
security.addUser("docker", "docker", "docker", "docker@example.com", true, "docker", ["nx-anonymous"])
/* Create docker and npm repositories. Their default configuration should be compliant with our requirements, except the docker registry creation. */
repository.createNpmHosted("npm-private")
def r = repository.createDockerHosted("onap", 8082, 0)
/* force basic authentication true by default, must set to false for docker repo. */
conf=r.getConfiguration()
conf.attributes("docker").set("forceBasicAuth", false)
repositoryManager.update(conf)'

usage () {
    echo "  This script is preparing Nexus data blob from docker images and npm packages"
    echo "      Usage:"
    echo "        ./$(basename $0) <config_file> [<target>]"
    echo "      "
    echo "      config_file is a file with defined variables, which are mandatory for this script"
    echo "      target is optional parameter where you can specify full path/name of resulted package"
    echo "      which replaces the value specified in configuration file"
    echo "      "
    echo "      Example: ./$(basename $0) ./package.conf  /root/nexus_data.tar"
    echo "      "
    echo "      Parameters need to be defined in configuration file:"
    echo "      "
    echo "      NXS_SRC_DOCKER_IMG_DIR    - directory of resource docker images"
    echo "      NXS_SRC_NPM_DIR           - directory of resource npm packages"
    echo "      NXS_DOCKER_IMG_LIST       - list of docker images to be pushed to Nexus repository"
    echo "      NXS_DOCKER_WO_LIST        - list of docker images which uses default repository"
    echo "      NXS_NPM_LIST              - list of npm packages to be published to Nexus repository"
    echo "      NEXUS_DATA_TAR            - target tarball of Nexus data path/name"
    echo "      NEXUS_DATA_DIR            - directory used for the Nexus blob build"
    echo "      NEXUS_IMAGE               - Sonatype/Nexus3 docker image which will be used for data blob creation"
    exit 1
}


#################################
# Prepare the local environment #
#################################

# Load the config file
if [ "${1}" == "-h" ] || [ -z "${1}" ]; then
    usage
elif [ -f ${1} ]; then
    . ${1}
else
    echo "Missing mandatory configuration file!"
    usage
    exit 1
fi

if [ -n "${2}" ]; then
    NEXUS_DATA_TAR="${2}"
fi

for VAR in NXS_SRC_DOCKER_IMG_DIR NXS_SRC_NPM_DIR NXS_DOCKER_IMG_LIST NXS_DOCKER_WO_LIST NXS_NPM_LIST NEXUS_DATA_TAR NEXUS_DATA_DIR NEXUS_IMAGE; do
    if [ -n "${!VAR}" ] ; then
        echo "${VAR} is set to ${!VAR}"
    else
        echo "${VAR} is not set and it is mandatory"
        FAIL="1"
    fi
done

if [ "${FAIL}" == "1" ]; then
    echo "One or more mandatory variables are not set"
    exit 1
fi

# Check the dependencies in the beginning

# Install jq
if yum list installed "jq" >/dev/null 2>&1; then
    echo "jq is already installed"
else
    yum install -y --setopt=skip_missing_names_on_install=False http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/j/jq-1.5-1.el7.x86_64.rpm
fi

# Install curl if necessary
if yum list installed "curl" >/dev/null 2>&1; then
    echo "curl is already installed"
else
    yum install -y --setopt=skip_missing_names_on_install=False curl
fi

# Install expect if necessary
if yum list installed "expect" >/dev/null 2>&1; then
    echo "expect is already installed"
else
    yum install -y --setopt=skip_missing_names_on_install=False expect
fi

# Install Docker (docker-ce in version 17.03 for RHEL) from online repositories if no version installed
if yum list installed "docker-ce" >/dev/null 2>&1 || which docker>/dev/null 2>&1; then
    echo "Docker is already installed"
else
    curl https://releases.rancher.com/install-docker/17.03.sh | sh
fi

# Prepare the Nexus configuration
NEXUS_CONFIG=$(echo "${NEXUS_CONFIG_GROOVY}" | jq -Rsc  '{"name":"configure", "type":"groovy", "content":.}')

# Add simulated domain names to /etc/hosts
cp /etc/hosts /etc/$(date +"%Y-%m-%d_%H-%M-%S")_hosts.bk
for DNS in ${SIMUL_HOSTS}; do
    echo "127.0.0.1 ${DNS}" >> /etc/hosts
done

# Backup the current docker registry settings
if [ -f /root/.docker/config.json ]; then
    mv /root/.docker/config.json /root/.docker/$(date +"%Y-%m-%d_%H-%M-%S")config.json.bk
fi

#################################
# Docker repository preparation #
#################################

# Load all necessary images
for ARCHIVE in $(sed $'s/\r// ; s/\:/\_/g ; s/\//\_/g ; s/$/\.tar/g' ${NXS_DOCKER_IMG_LIST} | awk '{ print $1 }'); do
    docker load -i ${NXS_SRC_DOCKER_IMG_DIR}/${ARCHIVE}
done

for ARCHIVE in $(sed $'s/\r// ; s/\:/\_/g ; s/\//\_/g ; s/$/\.tar/g' ${NXS_DOCKER_WO_LIST} | awk '{ print $1 }'); do
    docker load -i ${NXS_SRC_DOCKER_IMG_DIR}/${ARCHIVE}
done

# Tag docker images from default repository to simulated repository to be able to upload it to our private registry
for IMAGE in $(sed $'s/\r//' ${NXS_DOCKER_WO_LIST} | awk '{ print $1 }'); do
    docker tag ${IMAGE} ${DOCKER_REGISTRY}/${IMAGE}
done


################################
# Nexus repository preparation #
################################

# Load predefined Nexus image
docker load -i ${NEXUS_IMAGE}

# Prepare nexus-data directory
if [ -d ${NEXUS_DATA_DIR} ]; then
    if [ "$(docker ps -q -f name=nexus)" ]; then
        docker rm -f $(docker ps -aq -f name=nexus)
    fi
    cd ${NEXUS_DATA_DIR}/..
    mv ${NEXUS_DATA_DIR} $(date +"%Y-%m-%d_%H-%M-%S")_$(basename ${NEXUS_DATA_DIR})_bk
fi

mkdir -p ${NEXUS_DATA_DIR}
chown 200:200 ${NEXUS_DATA_DIR}
chmod 777 ${NEXUS_DATA_DIR}

# Save Nexus version to prevent/catch data incompatibility
docker images --no-trunc | grep sonatype/nexus3 | awk '{ print $1":"$2" "$3}' > ${NEXUS_DATA_DIR}/nexus.ver

# Start the Nexus
NEXUS_CONT_ID=$(docker run -d --rm -v ${NEXUS_DATA_DIR}:/nexus-data:rw --name nexus -p 8081:8081 -p 8082:8082 -p 80:8082 -p 10001:8082 sonatype/nexus3)
echo "Waiting for Nexus to fully start"
until curl -su admin:admin123 http://${NEXUS_DOMAIN}:8081/service/metrics/healthcheck | grep '"healthy":true' > /dev/null ; do
    printf "."
    sleep 3
done
echo -e "\nNexus started"

# Configure the nexus repository
curl -X POST --header 'Content-Type: application/json' --data-binary "${NEXUS_CONFIG}" http://admin:admin123@${NEXUS_DOMAIN}:8081/service/rest/v1/script
curl -X POST --header "Content-Type: text/plain" http://admin:admin123@${NEXUS_DOMAIN}:8081/service/rest/v1/script/configure/run

###########################
# Populate NPM repository #
###########################

# Configure NPM registry to our Nexus repository
npm config set registry ${NPM_REGISTRY}

# Login to NPM registry
/usr/bin/expect <<EOF
spawn npm login
expect "Username:"
send "${NEXUS_USERNAME}\n"
expect "Password:"
send "${NEXUS_PASSWORD}\n"
expect Email:
send "${NEXUS_EMAIL}\n"
expect eof
EOF

# Patch problematic package
cd ${NXS_SRC_NPM_DIR}
tar xvzf tsscmp-1.0.5.tgz
rm -f tsscmp-1.0.5.tgz
sed -i "s|https://registry.npmjs.org|http://${NEXUS_DOMAIN}:8081|g" package/package.json
sed -i "s|https://nexus.onap-me.novalocal|http://${NEXUS_DOMAIN}:8081|g" package/package.json
tar -zcvf tsscmp-1.0.5.tgz package
rm -rf package

# Push NPM packages to Nexus repository
for ARCHIVE in $(sed $'s/\r// ; s/\\@/\-/g ; s/$/\.tgz/g' ${NXS_NPM_LIST} | awk '{ print $1 }'); do
    npm publish --access public ${ARCHIVE}
done

##############################
# Populate Docker repository #
##############################

for REGISTRY in $(sed 's/\/.*//' ${NXS_DOCKER_IMG_LIST} | uniq) ${NEXUS_DOMAIN}:8082; do
    docker login -u "${NEXUS_USERNAME}" -p "${NEXUS_PASSWORD}" ${REGISTRY} > /dev/null
done

for IMAGE in $(sed $'s/\r//' ${NXS_DOCKER_WO_LIST} | awk '{ print $1 }'); do
    docker push ${DOCKER_REGISTRY}/${IMAGE}
done

for IMAGE in $(sed $'s/\r//' ${NXS_DOCKER_IMG_LIST} | awk '{ print $1 }'); do
    docker push ${IMAGE}
done

##############################
# Stop the Nexus and cleanup #
##############################

# Stop the Nexus
docker stop ${NEXUS_CONT_ID}

# Create the nexus-data package
cd ${NEXUS_DATA_DIR}/..
echo "Packing the ${NEXUS_DATA_DIR} dir"
until tar -cf ${NEXUS_DATA_TAR} $(basename ${NEXUS_DATA_DIR}); do
    printf "."
    sleep 5
done
echo "${NEXUS_DATA_TAR} has been created"

# Return the previous version of /etc/hosts back to its place
mv -f $(ls -tr /etc/*hosts.bk | tail -1) /etc/hosts

exit 0
