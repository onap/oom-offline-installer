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

# if onap.repo does not exists create it
mkdir -p $outdir
if [ ! -f "$outdir/onap.repo" ]; then
   cat > "$outdir/onap.repo" <<EOF
[ONAP]
name=Offline ONAP repository
baseurl=PATH
enabled=1
gpgcheck=0
EOF
fi

# this exact docker version is required by ONAP/beijing
# it should be available in centos docker repo
yumdownloader --resolve --destdir="$outdir" docker-ce-17.03.2.ce libtool-ltdl docker-ce-selinux

yumdownloader --resolve --destdir="$outdir" dnsmasq icewm firefox tigervnc-server perl*
createrepo "$outdir"
