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
RELATIVE_PATH=../ # relative path from this script to 'common-functions.sh'
if [ "$IS_COMMON_FUNCTIONS_SOURCED" != YES ] ; then
    SCRIPT_DIR=$(dirname "${0}")
    LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")
    . "${LOCAL_PATH}"/"${RELATIVE_PATH}"/common-functions.sh
fi

LIST_FILE="$1"
if [[ -z "$LIST_FILE" ]]; then
    echo "Missing list file"
    exit 1
fi
LIST_FILE=$(readlink -f "$LIST_FILE")


outdir="$2"
if [[ -z "$outdir" ]]; then
    echo "Missing output directory"
    exit 1
fi

lines=$(clean_list "$LIST_FILE" | wc -l)
cnt=1

# create output dir if not exists
mkdir -p "$outdir"

cd "$outdir"
for line in $(clean_list "$LIST_FILE)"; do
    echo "Downloading $cnt / $lines: $line"
    pip download $line
    cnt=$((cnt+1))
done
