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


# boilerplate
RELATIVE_PATH=./ # relative path from this script to 'common-functions.sh'
if [ "$IS_COMMON_FUNCTIONS_SOURCED" != YES ] ; then
    SCRIPT_DIR=$(dirname "${0}")
    LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")
    . "${LOCAL_PATH}"/"${RELATIVE_PATH}"/common-functions.sh
fi

tools="${LOCAL_PATH}"
message info "Reading configuration"
get_configuration

CTOOLS="$tools/creating_data"
LISTS_DIR="$tools/data_list"
DATA_DIR="$tools/../../resources/offline_data"
export NEXUS_HOST="https://$NEXUS_FQDN"
NPM_REGISTRY="$NEXUS_HOST/repository/npm-private/"

TOTAL=5
CURR=1

message info "Loading started: $(date)"

# backup config.json before we change it in docker-login
# however no use for restoring it found
mv ~/.docker/config.json ~/.docker/config.json_backup 2>/dev/null

echo "[Step $((CURR++))/$TOTAL Setting-up docker login for inserting docker images]"
$CTOOLS/docker-login.sh

echo "[Step $((CURR++))/$TOTAL Inserting docker images into local nexus]"
$CTOOLS/load-docker-images.sh "$DATA_DIR/docker_images_for_nexus"

echo "[Step $((CURR++))/$TOTAL Setting-up npm for inserting npm pkgs into local nexus]"

npm config set registry $NPM_REGISTRY

/usr/bin/expect <<EOF
spawn npm login
expect "Username:"
send "${NPM_USERNAME}\n"
expect "Password:"
send "${NPM_PASSWORD}\n"
expect Email:
send "${NPM_EMAIL}\n"
expect eof
EOF

echo "[WA] for tss package - this package uses already specified repo and dont accept our simulated domain"

cd $DATA_DIR/npm_tar
tar xvzf tsscmp-1.0.5.tgz
rm -f tsscmp-1.0.5.tgz
sed -i "s|https://registry.npmjs.org|${NPM_REGISTRY}|g" package/package.json
tar -zcvf tsscmp-1.0.5.tgz package
rm -rf package
cd -

echo "[Step $((CURR++))/$TOTAL Inserting npm packages into local nexus]"
$CTOOLS/upload-npm-pkgs.sh "$LISTS_DIR/npm_list.txt" "$DATA_DIR/npm_tar" "$NEXUS_HOST"

# onap is using different credentials for docker login which can be conflicted
# with ours so better to clean this-up
rm ~/.docker/config.json

message info "Loading finished: $(date)"
