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

OUTDIR="${1}"
if [[ -z "${OUTDIR}" ]]; then
    echo "Missing output dir"
    exit 1
fi


# create the package index
dpkg-scanpackages -m "${OUTDIR}" > "${OUTDIR}/Packages"
cat "${OUTDIR}/Packages" | gzip -9c > "${OUTDIR}/Packages.gz"

# create the Release file
echo 'deb [trusted=yes] http://repo.infra-server/ubuntu/xenial /' > "${OUTDIR}/onap.list"

exit 0
