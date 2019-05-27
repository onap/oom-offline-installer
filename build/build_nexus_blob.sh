#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE
#
#   Copyright 2018-2019 © Samsung Electronics Co., Ltd.
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

## The script requires following dependencies are installed: nodejs, jq, docker
## All required resources are expected in the upper directory
## created during download procedure as DATA_DIR
## All lists used must be in project data_lists directory

# Fail fast settings
set -e

TIMESTAMP="date +'%Y-%m-%d_%H-%M-%S'"
SCRIPT_LOG="/tmp/$(basename $0)_$(eval ${TIMESTAMP}).log"

# Log everything
exec &> >(tee -a "${SCRIPT_LOG}")

usage () {
    echo "  This script is preparing Nexus data blob from docker images and npm and pypi packages"
    echo "      Usage:"
    echo "        ./$(basename $0) <project version> [<target>]"
    echo "      "
    echo "      Example: ./$(basename $0) onap_3.0.1 /root/nexus_data"
    echo "      "
    echo "      Dependencies: nodejs, jq, docker"
    echo "      "
    exit 1
}

# Nexus repository location
NEXUS_DOMAIN="nexus"
NEXUS_PORT="8081"
NEXUS_DOCKER_PORT="8082"
NPM_REGISTRY="http://${NEXUS_DOMAIN}:${NEXUS_PORT}/repository/npm-private/"
PYPI_REGISTRY="http://${NEXUS_DOMAIN}:${NEXUS_PORT}/repository/pypi-private/"
DOCKER_REGISTRY="${NEXUS_DOMAIN}:${NEXUS_DOCKER_PORT}"
DEFAULT_REGISTRY="docker.io"

# Nexus repository credentials
NEXUS_USERNAME=admin
NEXUS_PASSWORD=admin123
NEXUS_EMAIL=admin@example.org

if [ "${1}" == "-h" ] || [ "${1}" == "--help"  ] || [ $# -eq 0 ]; then
    usage
else
    TAG="${1}"
fi

# Setting paths
LOCAL_PATH="$(readlink -f $(dirname ${0}))"
DATA_DIR="$(realpath ${LOCAL_PATH}/../../resources)"

if [ -z "${2}" ]; then
    NEXUS_DATA_DIR="${DATA_DIR}/nexus_data"
else
    NEXUS_DATA_DIR="${2}"
fi

# Setup directory with resources lists
LISTS_DIR="${LOCAL_PATH}/data_lists"

# Setup directories with resources for docker, npm and pypi
NXS_SRC_DOCKER_IMG_DIR="${DATA_DIR}/offline_data/docker_images_for_nexus"
NXS_SRC_NPM_DIR="${DATA_DIR}/offline_data/npm_tar"
NXS_SRC_PYPI_DIR="${DATA_DIR}/offline_data/pypi"

# Setup specific resources list based on the tag provided
NXS_DOCKER_IMG_LIST="${LISTS_DIR}/${TAG}-docker_images.list"
NXS_NPM_LIST="${LISTS_DIR}/$(sed 's/.$/x/' <<< ${TAG})-npm.list"
NXS_PYPI_LIST="${LISTS_DIR}/$(sed 's/.$/x/' <<< ${TAG})-pip_packages.list"

# Setup Nexus image used for build and install infra
INFRA_LIST="${LISTS_DIR}/infra_docker_images.list"
NEXUS_IMAGE="$(grep sonatype/nexus3 ${INFRA_LIST})"
NEXUS_IMAGE_TAR="${DATA_DIR}/offline_data/docker_images_infra/$(sed 's/\//\_/ ; s/$/\.tar/ ; s/\:/\_/' <<< ${NEXUS_IMAGE})"

# Setup default ports published to host as docker registry
PUBLISHED_PORTS="-p ${NEXUS_PORT}:${NEXUS_PORT} -p ${NEXUS_DOCKER_PORT}:${NEXUS_DOCKER_PORT}"

# Setup additional ports published to host based on simulated docker registries
for REGISTRY in $(sed -n '/\.[^/].*\//p' ${NXS_DOCKER_IMG_LIST} | sed -e 's/\/.*$//' | sort -u | grep -v ${DEFAULT_REGISTRY} || true); do
    if [[ ${REGISTRY} != *":"* ]]; then
        if [[ ${PUBLISHED_PORTS} != *"80:${NEXUS_DOCKER_PORT}"* ]]; then
            PUBLISHED_PORTS="${PUBLISHED_PORTS} -p 80:${NEXUS_DOCKER_PORT}"
        fi
    else
        REGISTRY_PORT="$(sed 's/^.*\:\([[:digit:]]*\)$/\1/' <<< ${REGISTRY})"
        if [[ ${PUBLISHED_PORTS} != *"${REGISTRY_PORT}:${NEXUS_DOCKER_PORT}"* ]]; then
            PUBLISHED_PORTS="${PUBLISHED_PORTS} -p ${REGISTRY_PORT}:${NEXUS_DOCKER_PORT}"
        fi
    fi
done

# Setup simulated domain names to be able to push all to private Nexus repository
SIMUL_HOSTS="$(sed -n '/\.[^/].*\//p' ${NXS_DOCKER_IMG_LIST} | sed -e 's/\/.*$// ; s/:.*$//' | sort -u | grep -v ${DEFAULT_REGISTRY} || true) ${NEXUS_DOMAIN}"

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
realmManager.enableRealm("PypiToken")
/* Create the docker user. */
security.addUser("docker", "docker", "docker", "docker@example.com", true, "docker", ["nx-anonymous"])
/* Create docker, npm and pypi repositories. Their default configuration should be compliant with our requirements, except the docker registry creation. */
repository.createNpmHosted("npm-private")
repository.createPyPiHosted("pypi-private")
def r = repository.createDockerHosted("onap", 8082, 0)
/* force basic authentication true by default, must set to false for docker repo. */
conf=r.getConfiguration()
conf.attributes("docker").set("forceBasicAuth", false)
repositoryManager.update(conf)'

# Prepare the Nexus configuration
NEXUS_CONFIG=$(echo "${NEXUS_CONFIG_GROOVY}" | jq -Rsc  '{"name":"configure", "type":"groovy", "content":.}')

#################################
# Prepare the local environment #
#################################

# Add simulated domain names to /etc/hosts
HOSTS_BACKUP="$(eval ${TIMESTAMP}_hosts.bk)"
cp /etc/hosts "/etc/${HOSTS_BACKUP}"
for DNS in ${SIMUL_HOSTS}; do
    echo "127.0.0.1 ${DNS}" >> /etc/hosts
done

# Backup the current docker registry settings
if [ -f ~/.docker/config.json ]; then
    DOCKER_CONF_BACKUP="$(eval ${TIMESTAMP}_config.json.bk)"
    mv ~/.docker/config.json "~/.docker/${DOCKER_CONF_BACKUP}"
fi

#################################
# Docker repository preparation #
#################################

# Load predefined Nexus image
docker load -i ${NEXUS_IMAGE_TAR}

# Load all necessary images
for ARCHIVE in $(sed $'s/\r// ; /^#/d ; s/\:/\_/g ; s/\//\_/g ; s/$/\.tar/g' ${NXS_DOCKER_IMG_LIST} | awk '{ print $1 }'); do
   docker load -i ${NXS_SRC_DOCKER_IMG_DIR}/${ARCHIVE}
done

################################
# Nexus repository preparation #
################################

# Prepare nexus-data directory
if [ -d ${NEXUS_DATA_DIR} ]; then
   if [ "$(docker ps -q -f name="${NEXUS_DOMAIN}")" ]; then
       echo "Removing container ${NEXUS_DOMAIN}"
       docker rm -f $(docker ps -aq -f name="${NEXUS_DOMAIN}")
   fi
   pushd ${NEXUS_DATA_DIR}/..
   NXS_BACKUP="$(eval ${TIMESTAMP})_$(basename ${NEXUS_DATA_DIR})_bk"
   mv ${NEXUS_DATA_DIR} "${NXS_BACKUP}"
   echo "${NEXUS_DATA_DIR} already exists - backing up to ${NXS_BACKUP}"
   popd
fi

mkdir -p ${NEXUS_DATA_DIR}
chown 200:200 ${NEXUS_DATA_DIR}
chmod 777 ${NEXUS_DATA_DIR}

# Save Nexus version to prevent/catch data incompatibility
docker images --no-trunc | grep sonatype/nexus3 | awk '{ print $1":"$2" "$3}' > ${NEXUS_DATA_DIR}/nexus.ver

# Start the Nexus
NEXUS_CONT_ID=$(docker run -d --rm -v ${NEXUS_DATA_DIR}:/nexus-data:rw --name ${NEXUS_DOMAIN} ${PUBLISHED_PORTS} ${NEXUS_IMAGE})
echo "Waiting for Nexus to fully start"
until curl -su ${NEXUS_USERNAME}:${NEXUS_PASSWORD} http://${NEXUS_DOMAIN}:${NEXUS_PORT}/service/metrics/healthcheck | grep '"healthy":true' > /dev/null ; do
    printf "."
    sleep 3
done
echo -e "\nNexus started"

# Configure the nexus repository
curl -sX POST --header 'Content-Type: application/json' --data-binary "${NEXUS_CONFIG}" http://${NEXUS_USERNAME}:${NEXUS_PASSWORD}@${NEXUS_DOMAIN}:${NEXUS_PORT}/service/rest/v1/script
curl -sX POST --header "Content-Type: text/plain" http://${NEXUS_USERNAME}:${NEXUS_PASSWORD}@${NEXUS_DOMAIN}:${NEXUS_PORT}/service/rest/v1/script/configure/run > /dev/null

###########################
# Populate NPM repository #
###########################

# Configure NPM registry to our Nexus repository
echo "Configure NPM registry to ${NPM_REGISTRY}"
npm config set registry "${NPM_REGISTRY}"

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
pushd ${NXS_SRC_NPM_DIR}
PATCHED_NPM="$(grep tsscmp ${NXS_NPM_LIST} | sed $'s/\r// ; s/\\@/\-/ ; s/$/\.tgz/')"
if [[ ! -z "${PATCHED_NPM}" ]] && ! zgrep -aq "${NPM_REGISTRY}" "${PATCHED_NPM}" 2>/dev/null; then
    tar xzf "${PATCHED_NPM}"
    rm -f "${PATCHED_NPM}"
    sed -i 's|\"registry\":\ \".*\"|\"registry\":\ \"'"${NPM_REGISTRY}"'\"|g' package/package.json
    tar -zcf "${PATCHED_NPM}" package
    rm -rf package
fi

# Push NPM packages to Nexus repository
for ARCHIVE in $(sed $'s/\r// ; s/\\@/\-/g ; s/$/\.tgz/g' ${NXS_NPM_LIST});do
   npm publish --access public ${ARCHIVE} > /dev/null
   echo "NPM ${ARCHIVE} pushed to Nexus"
done
popd

###############################
##  Populate PyPi repository  #
###############################

pushd ${NXS_SRC_PYPI_DIR}
for PACKAGE in $(sed $'s/\r//; s/==/-/' ${NXS_PYPI_LIST}); do
   twine upload -u "${NEXUS_USERNAME}" -p "${NEXUS_PASSWORD}" --repository-url ${PYPI_REGISTRY} ${PACKAGE}*
   echo "PYPI ${PACKAGE} pushed to Nexus"
done
popd

###############################
## Populate Docker repository #
###############################

# Login to simulated docker registries
for REGISTRY in $(sed -n '/\.[^/].*\//p' ${NXS_DOCKER_IMG_LIST} | sed -e 's/\/.*$//' | sort -u | grep -v ${DEFAULT_REGISTRY}) ${DOCKER_REGISTRY}; do
   echo "Docker login to ${REGISTRY}"
   docker login -u "${NEXUS_USERNAME}" -p "${NEXUS_PASSWORD}" ${REGISTRY} > /dev/null
done

# Push images to private nexus based on the list
# Images from default registry need to be tagged to private registry
# and those without defined repository in tag uses default repository 'library'
for IMAGE in $(sed $'s/\r// ; /^#/d' ${NXS_DOCKER_IMG_LIST} | awk '{ print $1 }'); do
    PUSH=""
    if [[ ${IMAGE} != *"/"* ]]; then
        PUSH="${DOCKER_REGISTRY}/library/${IMAGE}"
    elif [[ ${IMAGE} == *"${DEFAULT_REGISTRY}"* ]]; then
	if [[ ${IMAGE} == *"/"*"/"* ]]; then
            PUSH="$(sed 's/'"${DEFAULT_REGISTRY}"'/'"${DOCKER_REGISTRY}"'/' <<< ${IMAGE})"
        else
            PUSH="$(sed 's/'"${DEFAULT_REGISTRY}"'/'"${DOCKER_REGISTRY}"'\/library/' <<< ${IMAGE})"
        fi
    elif [[ -z $(sed -n '/\.[^/].*\//p' <<< ${IMAGE}) ]]; then
        PUSH="${DOCKER_REGISTRY}/${IMAGE}"
    fi
    if [[ ! -z ${PUSH} ]]; then
        docker tag ${IMAGE} ${PUSH}
    else
        PUSH="${IMAGE}"
    fi
    docker push ${PUSH}
    echo "${IMAGE} pushed as ${PUSH} to Nexus"
done

##############################
# Stop the Nexus and cleanup #
##############################

echo "Stopping Nexus and returning backups"

# Stop the Nexus
docker stop ${NEXUS_CONT_ID} > /dev/null

# Return backed up configuration files
mv -f "/etc/${HOSTS_BACKUP}" /etc/hosts

if [ -f "~/.docker/${DOCKER_CONF_BACKUP}" ]; then
    mv -f "~/.docker/${DOCKER_CONF_BACKUP}" ~/.docker/config.json
fi

# Return default settings
npm config set registry "https://registry.npmjs.org"

echo "Nexus blob is built"
exit 0
