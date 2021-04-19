#! /usr/bin/env bash

#   COPYRIGHT NOTICE STARTS HERE

#   Copyright 2019-2021 © Samsung Electronics Co., Ltd.
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
# Pre-requisites:
#  - python 3
#  - pip
#  - dev tools (libssl-dev in particular)
#  - venv
#
# Example install in Ubuntu 18.04
#   sudo apt install -y python3-pip
#   sudo apt install build-essential libssl-dev libffi-dev python3-dev
#   sudo apt install -y python3-venv
#
VENV_PATH=${VENV_PATH:-~/molecule_venv}

# Create virtual env
python3.8 -m venv ${VENV_PATH}

# Activate virtual env
source ${VENV_PATH}/bin/activate

# Install Molecule
if [ ! -z ${VIRTUAL_ENV} ]; then
    echo "Activated virtual env in ${VIRTUAL_ENV}"
    pip -q install -U pip
    pip -q install molecule==3.3.0 ansible==3.2.0 ansible-lint==5.0.7 docker molecule-docker==0.2.4 pytest-testinfra yamllint flake8
fi
