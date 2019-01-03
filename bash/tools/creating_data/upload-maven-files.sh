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

DATA_DIR="$1"
if [[ -z "$DATA_DIR" ]]; then
    # needs for example: /root/onap-offline-installer/http
    echo "Mising arg DATA_DIR"
    echo "Usage: $0 <path to http dir> <name of server> [<next server>...]"
    exit 1
fi

shift
cd "$DATA_DIR"

for server in $*; do
    echo "Uploading to server: $server"

    lines=$(find $server/ -type f | wc -l)
    count=1
    while read -r url; do
        echo "== pkg #$count of $lines =="
        count=$((count + 1))
        path="$url"
        echo "Uploading file: $url"
        curl -u admin:admin123 --upload-file $path http://$url

    done <<< "$(find $server/ -type f)"
done
