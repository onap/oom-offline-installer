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

FIND_PATH="/var/lib/docker/aufs/mnt/"

LIST_FILE="/tmp/npm.list"

: > $LIST_FILE

echo "gathering npm packages from $FIND_PATH"
while read -r line; do
    # yallist/2.1.2/package/package.json
    name=$(echo $line | cut -d '/' -f1 )
    ver=$(echo $line | cut -d '/' -f2 )
#    tag=$(echo $image|awk '{print $2}')
#    save_image "$name:$tag"
    echo "$name@$ver" >> $LIST_FILE

done <<< "$(find $FIND_PATH -path "*/.npm/*/package.json" | sed 's#^.*\.npm/\(.*\)$#\1#' | sort | uniq)"

