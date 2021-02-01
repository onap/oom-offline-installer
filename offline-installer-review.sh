#!/usr/bin/env bash
#   COPYRIGHT NOTICE STARTS HERE
#
#   Copyright 2018-2020 © Samsung Electronics Co., Ltd.
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
  local roles=("$@")
  local MOLECULE_RC
  for role in ${roles[@]}
    do
      if [ -f ${role}/molecule/default/molecule.yml ]; then
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
wget https://github.com/rancher/rke/releases/download/v1.0.4/rke_linux-amd64
ls -l

echo "----------   ONAP OFFLINE INSTALLER - CHANGE VERIFICATION START   ----------"
FAILED_ROLES=()
ALL_PLAYBOOKS=(`ls -d ansible/test/play-*`) # enumerate all playbook tests for later usage
# Setup environment
prep_ubuntu_16_04_for_molecule > ubuntu_preparation.log

# Check for changes in Ansible roles
ROLE_CHANGES=(`git diff HEAD^ HEAD --name-only ansible/roles | cut -f 1-3 -d "/" | sort -u`)
if [ -z "${ROLE_CHANGES}" ];  then
  echo "NO ANSIBLE ROLE TESTS REQUIRED"
else
  run_molecule "${ROLE_CHANGES[@]}"
fi

# Check for changes in Molecule tests
if ! $(git diff HEAD^ HEAD --exit-code --quiet ansible/test); then
  # If there are any changes in ansible/test area
  MOLECULE_CHANGES=(`git diff HEAD^ HEAD --name-only ansible/test | grep -v "ansible/test/play-.*/"`)
  if [ ${#MOLECULE_CHANGES[@]} -gt 0 ]; then
    # If detected changes that affect all playbook tests - run all
    run_molecule "${ALL_PLAYBOOKS[@]}"
    # memorize already tested playbooks
    TESTED_PLAYBOOKS=${ALL_PLAYBOOKS[@]}
  else
    # Changes only in ansible/test/play-* area - run tests only for changed playbook tests
    PLAYBOOKS=(`git diff HEAD^ HEAD --name-only ansible/test | cut -f 1-3 -d "/" | sort -u`)
    run_molecule "${PLAYBOOKS[@]}"
    # memorize already tested playbooks
    TESTED_PLAYBOOKS=${PLAYBOOKS[@]}
  fi
fi

# Check for changes in Ansible playbooks
PLAYBOOK_CHANGES=(`git diff HEAD^ HEAD --name-only --relative=ansible ansible/*yml | cut -f 1 -d "."`)
if [ ${#PLAYBOOK_CHANGES[@]} -gt 0 ]; then
  for playbook in ${PLAYBOOK_CHANGES[@]};
  do
    if [ -d ansible/test/play-${playbook} ]; then
      # If tests for this playbook are defined
      if [[ ! ${TESTED_PLAYBOOKS[*]} =~ ${playbook} ]]; then
        # AND weren't already run
        run_molecule "ansible/test/play-${playbook}"
      fi
    else
      # Warn that no tests are defined for this playbook
      echo "[WARNING] ---------- THERE ARE NO TESTS DEFINED FOR ${playbook}.yml PLAYBOOK ----------"
    fi
  done
fi

# Check for changes in Ansible group_vars or libraries
if ! $(git diff HEAD^ HEAD --exit-code --quiet --relative=ansible/group_vars) || \
   ! $(git diff HEAD^ HEAD --exit-code --quiet --relative=ansible/library); then
  # If there are any changes in ansible/{group_vars,libraries}
  # then run all playbook tests except those that've been
  # already run
  for playbook in ${ALL_PLAYBOOKS[@]};
  do
    if [[ ! ${TESTED_PLAYBOOKS[*]} =~ ${playbook} ]]; then
      run_molecule "${playbook}"
    fi
  done
fi

# if build was changed

if `git diff  HEAD^ HEAD --name-only | grep -q "build"`; then
  echo "TO DO: BUILD TEST" ;
else
  echo "NO BUILD TEST REQUIRED"
fi

# if documentation was changed

if `git diff  HEAD^ HEAD --name-only | grep -q "docs"`; then
  echo "TO DO: DOC TEST";
else
  echo "NO DOC TEST REQUIRED"
fi

# SUMMARY RESULTS

if [ -z ${FAILED_ROLES}  ]; then
  echo "All verification steps passed"
else
  echo "Verification failed for ${FAILED_ROLES[*]}"
  exit 1
fi
echo "----------   ONAP OFFLINE INSTALLER - CHANGE VERIFICATION END   ----------"
