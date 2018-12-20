#!/bin/bash

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
  echo "   ./$(basename $0) nfs_master_ip"
  exit 1
}

if [ "$#" -ne 1 ]; then
  echo "Missing NFS mater node"
  usage
fi

MASTER_IP=$1

#Install NFS common
#sudo apt-get update
#sudo apt-get install -y nfs-common

#Create NFS directory
sudo mkdir -p /dockerdata-nfs

#Mount the remote NFS directory to the local one
sudo mount $MASTER_IP:/dockerdata-nfs /dockerdata-nfs/
echo "$MASTER_IP:/dockerdata-nfs /dockerdata-nfs  nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | sudo tee -a /etc/fstab
