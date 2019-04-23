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

# Load common-functions library
. $(dirname ${0})/../common-functions.sh

LIST_FILE="${1}"

if [[ -z "$LIST_FILE" ]]; then
    LIST_FILE="all_npm_list.txt"
fi

outdir="$2"
if [[ -z "$outdir" ]]; then
    echo "Missing arg outdir"
    exit 1
fi

mkdir -p "$outdir"
cd "$outdir"
lines=$(clean_list "$LIST_FILE" | wc -l)
cnt=1
for line in $(clean_list "$LIST_FILE"); do
    echo "== pkg #$cnt of $lines =="
    npm pack $line
    cnt=$((cnt+1))
done