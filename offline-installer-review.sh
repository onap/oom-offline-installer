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

### This script performs Jenkins Change Verification for ONAP Offline Installer
# No parameters are expected
###

#if role was changed:
    ROLE_CHANGES=(`git diff  HEAD^ HEAD --name-only | grep "ansible/role" | cut -f 1-3 -d "/" | sort | uniq`)
    echo ${ROLE_CHANGES}
    if [ -z "${ROLE_CHANGES}" ];  then
        echo "NO ANSIBLE ROLES TESTs NEEDED"
    else
        for i in ${ROLE_CHANGES[@]}
          do
            sudo ./ansible/test/bin/ci-molecule.sh ${ROLE_CHANGES[i]}
          done
    fi

#if ansible/test was changed

    if `git diff  HEAD^ HEAD --name-only | grep -q "ansible/test"`;
        then echo "TO DO: FULL ANSIBLE TEST" ;
    fi


#if build was changed

    if `git diff  HEAD^ HEAD --name-only | grep -q "build"`;
        then echo "TO DO: BUILD TEST" ;
    fi

#if documentation was changed

    if `git diff  HEAD^ HEAD --name-only | grep -q "docs"`;
        then echo "TO DO: DOC TEST" ;
    fi

