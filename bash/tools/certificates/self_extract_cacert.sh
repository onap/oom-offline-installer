#! /bin/sh

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



extract_ca() {
    cpath=$1
    sed '0,/^#EOF#$/d' $0 > $cpath;
    echo "Certificate installed into: $cpath"
}

OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release)
OS_ID="${OS_ID%\"}"
OS_ID="${OS_ID#\"}"

if [ "$OS_ID" = "rhel" -o "$OS_ID" = "centos" ]; then
    # for centos/ rhel
    echo "Detected rhel like distribution"

    update-ca-trust force-enable
    extract_ca /etc/pki/ca-trust/source/anchors/rootCAcert.crt
    update-ca-trust extract

elif [ "$OS_ID" = "ubuntu" ]; then
    echo "Detected ubuntu distribution"

    mkdir -p /usr/local/share/ca-certificates/extra
    extract_ca /usr/local/share/ca-certificates/extra/rootCAcert.crt
    update-ca-certificates
else
    echo "OS $OS_ID is not supported"
    exit -2
fi

echo "** Please restart docker (because of reload new CA) **"

exit 0
#EOF#
