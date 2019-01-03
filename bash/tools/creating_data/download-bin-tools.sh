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
    echo "Missing arg outdir"
    exit 1
fi


mkdir -p "$outdir"
cd "$outdir"

download() {
    url="$1"
    url_file="${url%%\?*}"
    file=$(basename "$url_file")
    echo "Downloading $url"
    curl --retry 5 -y 10 -Y 10 --location  "$url" -o "$file"
}

download "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64"
mv ./jq-linux64 ./jq

download "https://storage.googleapis.com/kubernetes-release/release/v1.8.10/bin/linux/amd64/kubectl"

download "https://storage.googleapis.com/kubernetes-helm/helm-v2.8.2-linux-amd64.tar.gz"
tar -xf ./helm-v2.8.2-linux-amd64.tar.gz linux-amd64/helm -O > helm
rm ./helm-v2.8.2-linux-amd64.tar.gz

download "https://github.com/rancher/cli/releases/download/v0.6.7/rancher-linux-amd64-v0.6.7.tar.gz"
tar -xf ./rancher-linux-amd64-v0.6.7.tar.gz ./rancher-v0.6.7/rancher -O > rancher
rm ./rancher-linux-amd64-v0.6.7.tar.gz


chmod a+x ./helm ./jq ./kubectl ./rancher
