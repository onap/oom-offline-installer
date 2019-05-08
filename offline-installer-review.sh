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

function run_molecule() {
local role=("$@")
local MOLECULE_RC
for i  in ${role[@]}
  do
    if `find ${i} -name molecule.yml |  grep -q '.*'`; then
      ./ansible/test/bin/ci-molecule.sh ${i}
      MOLECULE_RC=$?
      if [ ${MOLECULE_RC} -ne "0" ]; then FAILED_ROLES+=(${i}); fi
    else
      echo "[WARNING] ---------- THERE ARE NO TESTS DEFINED FOR  ${i} ----------"
    fi
done
}

#######################################################################$
#                           MAIN                                      #$
#######################################################################$
FAILED_ROLES=()

#if ansible role was changed$$
ROLE_CHANGES=(`git diff  HEAD^ HEAD --name-only | grep "ansible/role" | cut -f 1-3 -d "/" | sort | uniq`)
if [ -z "${ROLE_CHANGES}" ];  then
  echo "NO ANSIBLE ROLE TESTS REQUIRED"
else
  run_molecule "${ROLE_CHANGES[@]}"
fi

#if ansible was changed

if `git diff  HEAD^ HEAD --name-only | grep -q "ansible/test"`; then
  PLAYBOOKS=(`find ansible/test -name "play-*"`)
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

