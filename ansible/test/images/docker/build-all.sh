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

BUILD_SCRIPT=${1:-build.sh}
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
# Run all build scripts in direct subdirectories
for buildfile in $(find ${SCRIPTPATH} -mindepth 2 -maxdepth 2 -name ${BUILD_SCRIPT});
do
  pushd $(dirname ${buildfile})
  . ${BUILD_SCRIPT}
  popd
done
