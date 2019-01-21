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

if [[ -z "$LISTS_DIR" ]]; then
    LISTS_DIR=.
    echo "Using default output directory ."
fi

OOM_PATH="$1"

if [[ -z "$OOM_PATH" ]]; then
    echo "Missing oom path"
    exit 1
fi


GOUTPUT="$LISTS_DIR/git_repos_list"
FOUTPUT="$LISTS_DIR/fetch_list.txt"

trim_last() {
   echo "${@:1:$#-1}";
}

TMP='/tmp/git_tmp_list'
:> $TMP

:> $FOUTPUT

echo "Gathering git repos and list possible html data"

while read -r chart; do
    out="$(helm template $(dirname "$chart") 2>/dev/null)"
    gitcmds=$(echo "$out" | grep 'git clone')

    if [[ -n "$gitcmds" ]] ; then
        while read gitcmd; do
            gitcmd=$(trim_last $gitcmd)
            repo_path=$(echo "$gitcmd" | sed 's#.*http://\(.*\)$#\1#')
            full="$gitcmd --bare $repo_path"
            echo "Cmd: $full"
            echo "$full" >> $TMP
        done <<< "$gitcmds"
    fi

    fetchcmds=$(echo "$out" | grep 'wget \|curl ' | grep -v 'HEALTH_CHECK_ENDPOINT\|PUT\|POST' )
    if [[ -n "$fetchcmds" ]] ; then
        while read fetchcmd; do
            echo "Fetch: $fetchcmd"
            echo "=== From: $chart" >> $FOUTPUT
            echo "$fetchcmd" >> $FOUTPUT
        done <<< "$fetchcmds"
    fi


done <<< "$(find $OOM_PATH -name Chart.yaml)"

sort $TMP | uniq > $GOUTPUT


