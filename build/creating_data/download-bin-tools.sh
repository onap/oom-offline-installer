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

usage () {
    echo "Usage:"
    echo -e "./$(basename $0) <project version> [destination directory]\n"
    echo "Examples:"
    echo "  ./$(basename $0) onap_2.0.0 ./git-repo"
}

if [ "${1}" == "-h" ] || [ -z "${1}" ] || [ -z "${2}"]; then
    usage
    exit 1
else
    TAG="${1}"
    OUTDIR="${2}"
fi

if [ "${TAG}" == onap_2.0.0 ]; then
    KUBECTL_VERSION=1.8.10
    HELM_VERSION=2.8.2
elif [ "${TAG}" == onap_3.0.0 ]; then
    KUBECTL_VERSION=1.11.2
    HELM_VERSION=2.9.1
fi

mkdir -p "$OUTDIR"
cd "$OUTDIR"

download() {
    url="$1"
    url_file="${url%%\?*}"
    file=$(basename "$url_file")
    echo "Downloading $url"
    curl --retry 5 -y 10 -Y 10 --location  "$url" -o "$file"
}

download "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

download "https://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz"
tar -xf ./helm-v${HELM_VERSION}-linux-amd64.tar.gz linux-amd64/helm -O > helm
rm -f ./helm-v${HELM_VERSION}-linux-amd64.tar.gz

chmod a+x ./helm ./kubectl

exit 0
