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

LIST_FILE="$1"
if [[ -z "$LIST_FILE" ]]; then
    echo "Mising arg LIST_FILE"
    exit 1
fi

DATA_DIR="$2"
if [[ -z "$DATA_DIR" ]]; then
    echo "Mising arg DATA_DIR"
    exit 1
fi

NEXUS_HOST="$3"
if [[ -z "$NEXUS_HOST" ]]; then
    echo "Mising arg NEXUS_HOST"
    exit 1
fi

npm config set registry $NEXUS_HOST/repository/npm-private/
# npm adduser moved to top

cd "$DATA_DIR"
lines=$(ls *.tgz | wc -l)
cnt=1
for line in *.tgz; do
    echo "== pkg #$cnt of $lines =="
    # yallist@2.1.2
    npm publish --access public "${line}"
    cnt=$((cnt+1))
done
