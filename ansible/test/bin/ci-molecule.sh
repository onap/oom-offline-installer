#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE

#   Copyright 2019 © Samsung Electronics Co., Ltd.
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

#
# This is a main wrapper script to run Molecule tests
# Main usage is for the CI usage to keep interface stable and the way to call
# Molecule can be adjusted in this script independently.
#

set -e

SCRIPT_DIR=$(dirname "${0}")
LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")

ROLE_PATH=$1
MOLECULE_CONTAINER=${MOLECULE_CONTAINER:-false}

echo "Build all pre-build images"
${LOCAL_PATH}/../images/docker/build-all.sh

# Use Molecule container
if [ "${MOLECULE_CONTAINER}" == "true" ]; then
    echo "Build Molecule-dev docker container"
    ${LOCAL_PATH}/../molecule-docker/build.sh
    MOLECULE_BINARY=${LOCAL_PATH}/../bin/molecule.sh

else # Install Molecule natively in the target platform
    echo "Install Molecule with virtualenv"
    source ${LOCAL_PATH}/../bin/install-molecule.sh
    MOLECULE_BINARY=molecule
fi

cd ${ROLE_PATH}
${MOLECULE_BINARY} --version
${MOLECULE_BINARY} test --all
cd -

