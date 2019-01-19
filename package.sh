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


# Scope of this packaging script is to generate tarfiles for offline installation
# Build of any additional artifacts is out of scope for this script

crash () {
    local exit_code="$1"
    local cause="$2"
    echo "Packaging script finished prematuraly"
    echo "Cause: $2"
    exit "${exit_code}"
}

usage () {
    echo "Usage:"
    echo "   ./$(basename $0) <project_name> <version>  <packaging_target_dir>"
    echo "Example: ./$(basename $0) onap-me 1.0.1  /tmp/package_onap-me_1.0.0"
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
    echo "tar file ${tar_name} created in target dir"
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
    cd ansible/docker
    ./build_ansible_image.sh
    if [ $? -ne 0 ]; then
        crash 666 "Building of ansible runner image failed."
    fi
    cd -
}

function create_sw_package {
    local pkg_root="${PACKAGING_TARGET_DIR}/onap"

    # Create tar package
    echo "[Creating software package]"

    # Create directory structure of the sw package
    mkdir -p "${pkg_root}"
    cp -r ansible "${pkg_root}"

    # Add additional files/dirs into package based on package.conf
    for item in "${SW_PACKAGE_ADDONS[@]}";do
        # all SW package addons are expected within ./ansible/application folder
        add_additions "${item}" "${pkg_root}/ansible/application"
    done

    # Helm charts handling
    echo "Helm charts handling"
    # Copy charts available for ansible playbook to use/move them to target server/dir
    mkdir -p "${pkg_root}"/ansible/application/helm_charts
    cp -r "${HELM_CHARTS_DIR}"/* "${pkg_root}"/ansible/application/helm_charts

    # Add metadata to the package
    add_metadata "${pkg_root}"/package.info

    # Create sw tar package
    echo "Creating tar file ..."
    PACKAGE_BASE_NAME="${SOFTWARE_PACKAGE_BASENAME}"
    create_tar "${pkg_root}" ${PACKAGE_BASE_NAME}-${PROJECT_NAME}-${PROJECT_VERSION}-sw.tar
    rm -rf "${pkg_root}"
}

function create_resource_package {
    local pkg_root="${PACKAGING_TARGET_DIR}/resources"

    # Create resource tar package
    echo "[Creating resource package]"

    # Create directory structure of the resource package
    mkdir -p "${pkg_root}"

    # Add artifacts into resource packagee based on package.conf config
    for item in "${EXTERNAL_BINARIES_PACKAGE_ADDONS[@]}";do
        if [ "$(basename $item)" == "resources" ]; then
            echo "Note: Packaging all resources at once"
            add_additions "${item}" "${PACKAGING_TARGET_DIR}"
        else
            add_additions "${item}" "${pkg_root}"
        fi
    done

    # tar file with nexus_data is expected, we should find and untar it
    # before resource.tar is created
    for i in `ls -1 ${pkg_root} | grep tar`; do
    tar tvf "${pkg_root}/${i}" | grep nexus_data &> /dev/null
    if [ $? -eq 0 ]; then
        echo "Debug: tar file with nexus blobs detected ${pkg_root}/${i}. Start unarchive ..."
        tar xf "${pkg_root}/${i}" -C "${pkg_root}" &> /dev/null
        echo "Debug: unarchive finished. Removing original file"
        rm -f "${pkg_root}/${i}"
    fi
    done

    echo "Creating tar file ..."
    PACKAGE_BASE_NAME="${SOFTWARE_PACKAGE_BASENAME}"
    create_tar "${pkg_root}" "${PACKAGE_BASE_NAME}-${PROJECT_NAME}-${PROJECT_VERSION}-resources.tar"
    rm -rf "${pkg_root}"
}

function create_aux_package {
    local pkg_root="${PACKAGING_TARGET_DIR}/aux"

    # Create aux resource tar package
    echo "Creating aux resource package"

    # Create directory structure of the aux resource package
    mkdir -p "${pkg_root}"

    # Add artifacts into resource packagee based on package.conf config
    for item in "${AUX_BINARIES_PACKAGE_ADDONS[@]}";do
        add_additions "${item}" "${pkg_root}"
    done

    echo "Creating tar file ..."
    PACKAGE_BASE_NAME="${SOFTWARE_PACKAGE_BASENAME}"
    create_tar "${pkg_root}" "${PACKAGE_BASE_NAME}-${PROJECT_NAME}-${PROJECT_VERSION}-aux-resources.tar"
    rm -rf "${pkg_root}"
}

#
# =================== Main ===================
#

PROJECT_NAME="$1"
PROJECT_VERSION="$2"
PACKAGING_TARGET_DIR="$3"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%S)

# ensure that package.conf is sourced even when package.sh executed from another place
SCRIPT_DIR=$(dirname "${0}")
LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")

# lets start from script directory as some path in script are relative
pushd "${LOCAL_PATH}"
source ./package.conf


if [ "$#" -lt 3 ]; then
    echo "Missing some mandatory parameter!"
    usage
    exit 1
fi

if [ ! -f "./package.conf" ]; then
    crash 2 "Mandatory config file ./package.conf missing!"
fi

# checking bash capability of parsing arrays
whotest[0]='test' || (crash 3 "Arrays not supported in this version of bash.")


# Prepare output directory for our packaging and create all tars

rm -rf ${PACKAGING_TARGET_DIR}
build_sw_artifacts
create_sw_package
create_resource_package

# This part will create aux package which consists of
# artifacts which can be added into offline nexus during runtime
if [ "${PREPARE_AUX_PACKAGE}" == "true" ]; then
    create_aux_package
else
    echo "AUX package won't be created"
fi

popd
