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
###############################################################################
# This script performs Jenkins Change Verification for ONAP Offline Installer #
# No parameters are expected                                                  #
###############################################################################

function prep_ubuntu_16_04_for_molecule() {
  sudo killall apt apt-get
  sudo apt-get --assume-yes install software-properties-common
  sudo add-apt-repository  --yes  ppa:deadsnakes/ppa
  sudo apt update
  sudo apt install --assume-yes python3.6
  sudo apt install --assume-yes python3.6-venv
}

function run_molecule() {
  prep_ubuntu_16_04_for_molecule
  local roles=("$@")
  local MOLECULE_RC
  for role in ${roles[@]}
    do
      if `find ${role} -name molecule.yml | grep -q '.*'`; then
        ./ansible/test/bin/ci-molecule.sh ${role}
        MOLECULE_RC=$?
        if [ ${MOLECULE_RC} -ne "0" ]; then FAILED_ROLES+=(${role}); fi
      else
        echo "[WARNING] ---------- THERE ARE NO TESTS DEFINED FOR  ${role} ----------"
      fi
  done
}

#######################################################################$
#                           MAIN                                      #$
#######################################################################$
FAILED_ROLES=()

#if ansible was changed

if `git diff  HEAD^ HEAD --name-only | grep -q "ansible/test"`; then
  PLAYBOOKS=(`find ansible/test -name "play-infrastructure"`)
  run_molecule "${PLAYBOOKS[@]}"
else
  echo "NO FULL ANSIBLE TEST REQUIRED";
fi

#if build was changed

if `git diff  HEAD^ HEAD --name-only | grep -q "build"`; then
  echo "TO DO: BUILD TEST" ;
else
  echo "NO BUILD TEST REQUIRED"
fi

#if documentation was changed

if `git diff  HEAD^ HEAD --name-only | grep -q "docs"`; then
  echo "TO DO: DOC TEST";
else
  echo "NO DOC TEST REQUIRED"
fi

#SUMMARY RESULTS

if [ -z ${FAILED_ROLES}  ]; then
  echo "All verification steps passed"
else
  echo "Verification failed for ${FAILED_ROLES[*]}"
  exit 1
fi

