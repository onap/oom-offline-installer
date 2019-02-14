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


# Scope of this packaging script is to generate tarfiles for offline installation
# Build of any additional artifacts is out of scope for this script
set -e

crash () {
    local exit_code="$1"
    local cause="$2"
    echo "Packaging script finished prematurely"
    echo "Cause: $2"
    exit "${exit_code}"
}

usage () {
    echo "Usage:"
    echo "   ./$(basename $0) <project_name> <version>  <packaging_target_dir> [--conf <file>]"
    echo "Example: ./$(basename $0) myproject 1.0.1 /tmp/package --conf ~/myproject.conf"
    echo "packaging_target_dir will be created if does not exist. All tars will be produced into it."
}

function create_tar {
    local tar_dir="$1"
    local tar_name="$2"

    cd ${tar_dir}
    touch ${tar_name} # Trick to avoid sporadic "tar: .: file changed as we read it" warning message
    tar --exclude=${tar_name} -cf ../${tar_name} .
    cd - &> /dev/null # Trick to avoid printing new dir on stdout

    # Remove packaged folders
    find ${tar_dir}/* -maxdepth 0 -type d -exec rm -rf '{}' \;
    # Remove packaged files
    find ${tar_dir}/* ! -name ${tar_name} -exec rm '{}' \;
    echo "Tar file created to $(dirname ${tar_dir})/${tar_name}"
}

function create_pkg {
    local pkg_type="$1"
    echo "[Creating ${pkg_type} package]"
    create_tar "${PKG_ROOT}" offline-${PROJECT_NAME}-${PROJECT_VERSION}-${pkg_type}.tar
    rm -rf "${PKG_ROOT}"
}

function add_metadata {
    local metafile="$1"
    echo "Project name: ${PROJECT_NAME}" >> "${metafile}"
    echo "Project version: ${PROJECT_VERSION}" >> "${metafile}"
    echo "Package date: ${TIMESTAMP}" >> "${metafile}"
}

function add_additions {
    local source="$1"
    local target="$2"
    if [ -d "${source}" ]; then
        mkdir -p "${target}/$(basename $source)"
        cp -r "${source}" "${target}"
        echo "Adding directory  ... $(basename $source)"
    else
        if [ -f "${source}" ]; then
             cp "${source}" "${target}"
             echo "Adding file       ... $(basename $source)"
        else
             crash 4 "Invalid source specified for packaging: $1"
        fi
    fi
}

function build_sw_artifacts {
    cd ${LOCAL_PATH}/../ansible/docker
    ./build_ansible_image.sh
    if [ $? -ne 0 ]; then
        crash 5 "Building of ansible runner image failed."
    fi
    cd -
}

function create_sw_package {
    PKG_ROOT="${PACKAGING_TARGET_DIR}/sw"

    # Create directory structure of the sw package
    mkdir -p "${PKG_ROOT}"
    cp -r ${LOCAL_PATH}/../ansible "${PKG_ROOT}"

    # Add application additional files/dirs into package based on package.conf
    for item in "${APP_CONFIGURATION[@]}";do
        # all SW package addons are expected within ./ansible/application folder
        add_additions "${item}" "${PKG_ROOT}/${APPLICATION_FILES_IN_PACKAGE}"
    done

    # Application Helm charts
    # To be consistent with resources and aux dir, create charts dir even if no charts provided.
    mkdir -p ${PKG_ROOT}/${HELM_CHARTS_DIR_IN_PACKAGE}
    if [ ! -z "${HELM_CHARTS_DIR}" ];
    then
        echo "Add application Helm charts"
        # Copy charts available for ansible playbook to use/move them to target server/dir
        cp -r "${HELM_CHARTS_DIR}"/* ${PKG_ROOT}/${HELM_CHARTS_DIR_IN_PACKAGE}
    else
        echo "No Helm charts defined, no application will be automatically installed by this package!"
    fi

    # Add metadata to the package
    add_metadata "${PKG_ROOT}"/package.info

    # Create sw tar package
    create_pkg sw
}

function create_resource_package {
    PKG_ROOT="${PACKAGING_TARGET_DIR}/resources"

    # Create directory structure of the resource package
    mkdir -p "${PKG_ROOT}"

    # Add artifacts into resource package based on package.conf config
    if [ ! -z ${APP_BINARY_RESOURCES_DIR} ]; then
        cp -r ${APP_BINARY_RESOURCES_DIR}/* ${PKG_ROOT}
    fi

    # tar file with nexus_data is expected, we should find and untar it
    # before resource.tar is created
    for i in `ls -1 ${PKG_ROOT} | grep tar`; do
        tar tvf "${PKG_ROOT}/${i}" | grep nexus_data &> /dev/null
        if [ $? -eq 0 ]; then
            echo "Debug: tar file with nexus blobs detected ${PKG_ROOT}/${i}. Start unarchive ..."
            tar xf "${PKG_ROOT}/${i}" -C "${PKG_ROOT}" &> /dev/null
            echo "Debug: unarchive finished. Removing original file"
            rm -f "${PKG_ROOT}/${i}"
        fi
    done

    create_pkg resources
}

function create_aux_package {
    PKG_ROOT="${PACKAGING_TARGET_DIR}/aux"

    # Create directory structure of the aux resource package
    mkdir -p "${PKG_ROOT}"

    # Add artifacts into resource packagee based on package.conf config
    for item in "${APP_AUX_BINARIES[@]}";do
        add_additions "${item}" "${PKG_ROOT}"
    done

    create_pkg aux-resources
}

#
# =================== Main ===================
#

PROJECT_NAME="$1"
PROJECT_VERSION="$2"
PACKAGING_TARGET_DIR="$3"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%S)
SCRIPT_DIR=$(dirname "${0}")
LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")

# Relative location inside the package for application related files.
# Application means Kubernetes application installed by Helm charts on ready cluster (e.g. onap).
APPLICATION_FILES_IN_PACKAGE="ansible/application"

# Relative location inside the package to place Helm charts to be available for
# Ansible process to transfer them into machine (infra node) running Helm repository.
# NOTE: This is quite hardcoded place to put them and agreement with Ansible code
# is done in ansible/group_vars/all.yml with variable "app_helm_charts_install_directory"
# whihc value must match to value of this variable (with exception of slash '/'
# prepended so that ansible docker/chroot process can see the dir).
# This variable can be of course changed in package.conf if really needed if
# corresponding ansible variable "app_helm_charts_install_directory" value
# adjusted accordingly.
HELM_CHARTS_DIR_IN_PACKAGE="${APPLICATION_FILES_IN_PACKAGE}/helm_charts"

if [ "$#" -lt 3 ]; then
    echo "Missing some mandatory parameter!"
    usage
    exit 1
fi

CONF_FILE=""
for arg in "$@"; do
  shift
  case "$arg" in
    -c|--conf)
        CONF_FILE="$1" ;;
    *)
        set -- "$@" "$arg"
  esac
done

if [ -z ${CONF_FILE} ]; then
    CONF_FILE=${LOCAL_PATH}/package.conf # Fall to default conf file
fi

if [ ! -f ${CONF_FILE} ]; then
    crash 2 "Mandatory config file missing! Provide it with --conf option or ${LOCAL_PATH}/package.conf"
fi

source ${CONF_FILE}
pushd ${LOCAL_PATH}

# checking bash capability of parsing arrays
whotest[0]='test' || (crash 3 "Arrays not supported in this version of bash.")


# Prepare output directory for our packaging and create all tars

rm -rf ${PACKAGING_TARGET_DIR}
build_sw_artifacts
create_sw_package
create_resource_package
create_aux_package

popd
