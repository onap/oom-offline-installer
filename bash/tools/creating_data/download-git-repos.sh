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

lists_dir="$1"

if [[ -z "$lists_dir" ]]; then
    echo "Missing argument for lists_dir"
    exit 1
fi

outdir="$2"
if [[ -z "$outdir" ]]; then
    outdir="./git-repo"
fi

mkdir -p "$outdir"
cd "$outdir"
# NOTE: will be better to use sh extension?
sh $lists_dir/git_manual_list
sh $lists_dir/git_repos_list

