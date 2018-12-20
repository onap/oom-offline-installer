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

script_dir="$(dirname ${BASH_SOURCE[0]})"
tools=$(readlink -f "$script_dir")

echo "WARNING: This script won't be used except rare internal usage, it's just illustrating how we collected lists of artifacts to be downloaded. It's already deprecated"

TOOLS="$tools/creating_data"
export LISTS_DIR="$tools/data_list"
export ONAP_SERVERS="oom-beijing-postRC2-master oom-beijing-postRC2-compute1 oom-beijing-postRC2-compute2"
OOM_PATH="$tools/../../resources/oom"

$TOOLS/remote-list-gathering.sh
$TOOLS/make-git-http-list.sh "$OOM_PATH"


