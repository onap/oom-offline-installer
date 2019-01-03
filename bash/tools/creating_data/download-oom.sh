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

outdir="$1"
if [[ -z "$outdir" ]]; then
    echo "Missing output dir"
    exit 1
fi
patch_file="$2"
if [[ -z "$patch_file" ]]; then
    echo "Missing patch file"
    exit 1
fi

cd "$outdir"
git clone https://github.com/onap/oom.git
cd oom
echo "Checkout base commit which will be patched"
git checkout -b patched_beijing bf47d706fc8b94fd1232960e90329a9a532c6a7b

patch -p1 < "$patch_file"

