#! /bin/bash

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


self="$0"
tools_dir=$(dirname "$self")

TARGET_FILE="./install_cacert.sh"

cat "$tools_dir/certificates/self_extract_cacert.sh" "$tools_dir/../../live/certs/rootCAcert.crt" > $TARGET_FILE
chmod a+x $TARGET_FILE
echo "Created self installation file: $TARGET_FILE"
