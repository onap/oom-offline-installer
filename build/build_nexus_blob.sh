#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE
#
#   Copyright 2018-2020© Samsung Electronics Co., Ltd.
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

## The script requires following dependencies are installed: nodejs, jq, docker, twine, expect
## All required resources are expected in the upper directory created during
## download procedure as DATA_DIR or in the directory given as --input-directory
## All lists used must be in project data_lists directory or in the directory given
## as --resource-list-directory

# Fail fast settings
set -e

TIMESTAMP="date +'%Y-%m-%d_%H-%M-%S'"
SCRIPT_LOG="/tmp/$(basename $0)_$(eval ${TIMESTAMP}).log"

# Log everything
exec &> >(tee -a "${SCRIPT_LOG}")

# Nexus repository properties
NEXUS_DOMAIN="nexus"
NEXUS_HOST="127.0.0.1"
NEXUS_EXPOSED_PORT="8081"
NEXUS_PORT=${NEXUS_EXPOSED_PORT}
NEXUS_DOCKER_EXPOSED_PORT="8082"
NEXUS_DOCKER_PORT=${NEXUS_DOCKER_EXPOSED_PORT}
DEFAULT_REGISTRY="docker.io"

# Nexus repository credentials
NEXUS_USERNAME=admin
NEXUS_PASSWORD=admin123
NEXUS_EMAIL=admin@example.org

# Setting paths
LOCAL_PATH="$(readlink -f $(dirname ${0}))"

# Defaults
DOCKER_LOAD="false"
NPM_PUSH="false"
PYPI_PUSH="false"
DATA_DIR="$(realpath ${LOCAL_PATH}/../../resources)"
NEXUS_DATA_DIR="${DATA_DIR}/nexus_data"
LISTS_DIR="${LOCAL_PATH}/data_lists"

# Required dependencies
COMMANDS=(jq docker)

usage () {
    echo "
    Usage: $(basename $0) [OPTION...] [FILE]...

    This script prepares Nexus repositories data blobs for ONAP

    Following dependencies are required: nodejs, jq, docker, twine, expect
    By default, without any lists or dirs provided, the resources are expected as downloaded
    during download process and default lists will be used to build the Nexus blob in the same
    resources dir

    Examples:
        $(basename $0) --input-directory </path/to/downloaded/files/dir> -ld --output-directory
           </path/to/output/dir> --resource-list-directory </path/to/dir/with/resource/list>
           # Docker images, npms and pypi packages will be loaded from specified directory
           # and the blob is created
        $(basename $0) -d </path/to/docker/images/list> -d </path/to/another/docker/images/list>
        -n </path/to/npm/list> -p </path/to/pip/list>
           # Docker images, npms and pypi packages will be pushed to Nexus based and provided data
           # lists (multiple lists can be provided)

     -d  | --docker                     use specific list of docker images to be pushed into Nexus
                                        (in case of -ld used, this list will be used for loading of
                                        the images)
     -h  | --help                       print this usage
     -i  | --input-directory            use specific directory containing resources needed to
                                        create nexus blob
                                        The structure of this directory must organized as described
                                        in build guide
     -ld | --load-docker-images         load docker images from resource directory
     -n  | --npm                        list of npm packages to be pushed into Nexus
     -o  | --output-directory           use specific directory for the target blob
     -p  | --pypi                       use specific list of pypi packages to be pushed into Nexus
     -rl | --resource-list-directory    use specific directory with docker, pypi and npm lists
     -c  | --container-name             use specific Nexus docker container name
     -NP | --nexus-port                 use specific port for published Nexus service
     -DP | --docker-port                use specific port for published Nexus docker registry port
    "
    exit 1
}

load_docker_images () {
    for ARCHIVE in $(sed $'s/\r// ; /^#/d ; s/\:/\_/g ; s/\//\_/g ; s/$/\.tar/g' ${1} | awk '{ print $1 }'); do
        docker load -i ${NXS_SRC_DOCKER_IMG_DIR}/${ARCHIVE}
    done
}

prepare_npm () {
    # Configure NPM registry to our Nexus repository
    echo "Configure NPM registry to ${NPM_REGISTRY}"
    npm config set registry "${NPM_REGISTRY}"

    # Login to NPM registry
    /usr/bin/expect <<- EOF
	spawn npm login
	expect "Username:"
	send "${NEXUS_USERNAME}\n"
	expect "Password:"
	send "${NEXUS_PASSWORD}\n"
	expect Email:
	send "${NEXUS_EMAIL}\n"
	expect eof
	EOF
}

patch_npm () {
    # Patch problematic package
    PATCHED_NPM="$(grep tsscmp ${1} | sed $'s/\r// ; s/\\@/\-/ ; s/$/\.tgz/')"
    if [[ ! -z "${PATCHED_NPM}" ]] && ! zgrep -aq "${NPM_REGISTRY}" "${PATCHED_NPM}" 2>/dev/null
    then
        tar xzf "${PATCHED_NPM}"
        rm -f "${PATCHED_NPM}"
        sed -i 's|\"registry\":\ \".*\"|\"registry\":\ \"'"${NPM_REGISTRY}"'\"|g' package/package.json
        tar -zcf "${PATCHED_NPM}" package
        rm -rf package
    fi
}

push_npm () {
    for ARCHIVE in $(sed $'s/\r// ; s/\\@/\-/g ; s/$/\.tgz/g' ${1}); do
        npm publish --access public ${ARCHIVE} > /dev/null
        echo "NPM ${ARCHIVE} pushed to Nexus"
    done
}

push_pip () {
    for PACKAGE in $(sed $'s/\r//; s/==/-/' ${1}); do
        twine upload -u "${NEXUS_USERNAME}" -p "${NEXUS_PASSWORD}" --repository-url ${PYPI_REGISTRY} ${PACKAGE}* > /dev/null
        echo "PYPI ${PACKAGE} pushed to Nexus"
    done
}

docker_login () {
    echo "Docker login to ${DOCKER_REGISTRY}"
    echo -n "${NEXUS_PASSWORD}" | docker --config "${DOCKER_CONFIG_DIR}" login -u "${NEXUS_USERNAME}" --password-stdin ${DOCKER_REGISTRY} > /dev/null
}

push_docker () {
    for IMAGE in $(sed $'s/\r// ; /^#/d' ${1} | awk '{ print $1 }'); do
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
        else
            # substitute all host names with $DOCKER_REGISTRY
            repo_host=$(sed -e 's/\/.*$//' <<< ${IMAGE})
            PUSH="$(sed -e 's/'"${repo_host}"'/'"${DOCKER_REGISTRY}"'/' <<< ${IMAGE})"
        fi
        docker tag ${IMAGE} ${PUSH}
        docker --config "${DOCKER_CONFIG_DIR}" push ${PUSH}
        # Remove created tag
        docker rmi ${PUSH}
        echo "${IMAGE} pushed as ${PUSH} to Nexus"
    done
}

validate_container_name () {
    # Verify $1 is a valid hostname
    if ! echo "${1}" | egrep -q "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$";
    then
        echo "ERROR: ${1} is not a valid name!"
        exit 1;
    fi
}

while [ "${1}" != "" ]; do
    case ${1} in
        -d | --docker )                    shift
                                           NXS_DOCKER_IMG_LISTS+=("$(realpath ${1})")
                                           ;;
        -i | --input-directory )           shift
                                           DATA_DIR="$(realpath ${1})"
                                           ;;
        -ld | --load-docker-images )       DOCKER_LOAD="true"
                                           ;;
        -n | --npm )                       NPM_PUSH="true"
                                           COMMANDS+=(expect npm)
                                           shift
                                           NXS_NPM_LISTS+=("$(realpath ${1})")
                                           ;;
        -c | --container-name )            shift
                                           validate_container_name "${1}"
                                           NEXUS_DOMAIN="${1}"
                                           ;;
        -o | --output-directory )          shift
                                           NEXUS_DATA_DIR="$(realpath ${1})"
                                           ;;
        -p | --pypi )                      PYPI_PUSH="true"
                                           COMMANDS+=(twine)
                                           shift
                                           NXS_PYPI_LISTS+=("$(realpath ${1})")
                                           ;;
        -rl | --resource-list-directory )  shift
                                           LISTS_DIR="$(realpath ${1})"
                                           ;;
        -NP | --nexus-port )               shift
                                           NEXUS_PORT="${1}"
                                           ;;
        -DP | --docker-port )              shift
                                           NEXUS_DOCKER_PORT="${1}"
                                           ;;
        -h | --help )                      usage
                                           ;;
        *)                                 usage
                                           ;;
    esac
    shift
done

# Verify all dependencies are available in PATH
FAILED_COMMANDS=()
for cmd in ${COMMANDS[*]}; do
    command -v $cmd >/dev/null 2>&1 || FAILED_COMMANDS+=($cmd)
done

if [ ${#FAILED_COMMANDS[*]} -gt 0 ]; then
    echo "Following commands where not found in PATH and are required:"
    echo ${FAILED_COMMANDS[*]}
    echo "Aborting."
    exit 1
fi

# Nexus repository locations
NPM_REGISTRY="http://${NEXUS_HOST}:${NEXUS_PORT}/repository/npm-private/"
PYPI_REGISTRY="http://${NEXUS_HOST}:${NEXUS_PORT}/repository/pypi-private/"
DOCKER_REGISTRY="${NEXUS_HOST}:${NEXUS_DOCKER_PORT}"

# Setup directories with resources for docker, npm and pypi
NXS_SRC_DOCKER_IMG_DIR="${DATA_DIR}/offline_data/docker_images_for_nexus"
NXS_SRC_NPM_DIR="${DATA_DIR}/offline_data/npm_tar"
NXS_SRC_PYPI_DIR="${DATA_DIR}/offline_data/pypi"

# Setup specific resources lists
NXS_INFRA_LIST="${LISTS_DIR}/infra_docker_images.list"
NXS_DOCKER_IMG_LIST="${LISTS_DIR}/onap_docker_images.list"
NXS_RKE_DOCKER_IMG_LIST="${LISTS_DIR}/rke_docker_images.list"
NXS_K8S_DOCKER_IMG_LIST="${LISTS_DIR}/k8s_docker_images.list"

# Setup Nexus image used for build and install infra
NEXUS_IMAGE="$(grep sonatype/nexus3 ${NXS_INFRA_LIST})"
NEXUS_IMAGE_TAR="${DATA_DIR}/offline_data/docker_images_infra/$(sed 's/\//\_/ ; s/$/\.tar/ ; s/\:/\_/' <<< ${NEXUS_IMAGE})"

# Set default lists if nothing specific defined by user
if [ ${#NXS_DOCKER_IMG_LISTS[@]} -eq 0 ]; then
    NXS_DOCKER_IMG_LISTS=("${NXS_DOCKER_IMG_LIST}" "${NXS_RKE_DOCKER_IMG_LIST}" "${NXS_K8S_DOCKER_IMG_LIST}")
fi

# Create Docker client config dir
DOCKER_CONFIG_DIR=$(mktemp -p /tmp -d .docker.XXXXXXXX)

# Setup default ports published to host as docker registry
PUBLISHED_PORTS="-p ${NEXUS_PORT}:${NEXUS_EXPOSED_PORT} -p ${NEXUS_DOCKER_PORT}:${NEXUS_DOCKER_EXPOSED_PORT}"

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
# Docker repository preparation #
#################################

if [ "${DOCKER_LOAD}" == "true" ]; then
    # Load predefined Nexus image
    docker load -i ${NEXUS_IMAGE_TAR}
    # Load all necessary images
    for DOCKER_IMG_LIST in "${NXS_DOCKER_IMG_LISTS[@]}"; do
        load_docker_images "${DOCKER_IMG_LIST}"
    done
fi

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
# Adding commit informations to have link to data from which the blob was built
cat >> ${NEXUS_DATA_DIR}/nexus.ver << INFO
nexus_image=$(docker image ls ${NEXUS_IMAGE} --no-trunc --format "{{.Repository}}:{{.Tag}}\nnexus_image_digest={{.ID}}")
$(for INDEX in ${!NXS_DOCKER_IMG_LISTS[@]}; do printf 'used_image_list%s=%s\n' "$INDEX" "$(sed 's/^.*\/\(.*\)$/\1/' <<< ${NXS_DOCKER_IMG_LISTS[$INDEX]})"; done)
$(sed -n 's/^.*OOM\ commit\ /oom_repo_commit=/p' ${NXS_DOCKER_IMG_LISTS[@]})
installer_repo_commit=$(git --git-dir="${LOCAL_PATH}/../.git" rev-parse HEAD)
INFO

# Start the Nexus
NEXUS_CONT_ID=$(docker run -d --rm -v ${NEXUS_DATA_DIR}:/nexus-data:rw --name ${NEXUS_DOMAIN} ${PUBLISHED_PORTS} ${NEXUS_IMAGE})
echo "Waiting for Nexus to fully start"
until curl -su ${NEXUS_USERNAME}:${NEXUS_PASSWORD} http://${NEXUS_HOST}:${NEXUS_PORT}/service/metrics/healthcheck | grep '"healthy":true' > /dev/null ; do
    printf "."
    sleep 3
done
echo -e "\nNexus started"

# Configure the nexus repository
curl -sX POST --header 'Content-Type: application/json' --data-binary "${NEXUS_CONFIG}" http://${NEXUS_USERNAME}:${NEXUS_PASSWORD}@${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/script
curl -sX POST --header "Content-Type: text/plain" http://${NEXUS_USERNAME}:${NEXUS_PASSWORD}@${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/script/configure/run > /dev/null

###########################
# Populate NPM repository #
###########################
if [ $NPM_PUSH == "true" ]; then
    prepare_npm
    pushd ${NXS_SRC_NPM_DIR}
    for NPM_LIST in "${NXS_NPM_LISTS[@]}"; do
        patch_npm "${NPM_LIST}"
        push_npm "${NPM_LIST}"
    done
    popd
    # Return default settings
    npm logout
    npm config set registry "https://registry.npmjs.org"
fi

###############################
##  Populate PyPi repository  #
###############################
if [ $PYPI_PUSH == "true" ]; then
    pushd ${NXS_SRC_PYPI_DIR}
    for PYPI_LIST in "${NXS_PYPI_LISTS[@]}"; do
        push_pip "${PYPI_LIST}"
    done
    popd
fi

###############################
## Populate Docker repository #
###############################

# Login to docker registry simulated by Nexus container
# Push images to private nexus based on the lists
# All images need to be tagged to simulated registry
# and those without defined repository in tag use default repository 'library'
docker_login
for DOCKER_IMG_LIST in "${NXS_DOCKER_IMG_LISTS[@]}"; do
    push_docker "${DOCKER_IMG_LIST}"
done

##############################
# Stop the Nexus and cleanup #
##############################

echo "Stopping Nexus"

# Stop the Nexus
docker stop ${NEXUS_CONT_ID} > /dev/null

# Drop temporary Docker client config dir
rm -rf ${DOCKER_CONFIG_DIR}

echo "Nexus blob is built"
exit 0
