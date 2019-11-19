#!/bin/bash

#Variables
SCRIPT_PATH=$0
CMD=$(basename "$0")

REPO_IMAGE=${1}

#Server with connection to internet
SERVER=${2}

#User and password for docker login on $SERVER
REMOTE_USER=
REMOTE_PASSWD=

#User and password for docker login on localhost
LOCAL_USER=
LOCAL_PASSWD=
IMAGE=`sed 's/^[^/]*\///g' <<< ${1}`

help()
{
cat <<EOF
${CMD} - tool for downloading image and adding it to offline nexus repository

Usage
        $SCRIPT_PATH <repository>/<image>:<tag> <server>

        $SCRIPT_PATH <repository>/<image>:<tag> <server> --local-repo example.repository

MANDATORY PARAMETERS:
<repository>/<image>:<tag> == image to be downloaded (e.g. nexus3.onap.org:10001/library/busybox:latest)
<server> == server with connection to internet and docker installed

OPTIONAL PARAMETERS:
--remote-user == user for docker login on <server>
--remote-passwd == password for cicd-user
--local-user == user for docker login on localhost
--local-passwd == password for local-user
--local-repo == local repository where new image should be pushed

EOF
}

if [ $# -lt 2 ]; then
  help
  exit 1
fi

#Set up parameters
while [[ $# -gt 2 ]]; do
    case $3 in
        --remote-user)          REMOTE_USER=$4
                                ;;
        --remote-passwd)        REMOTE_PASSWD=$4
                                ;;
        --local-user)           LOCAL_USER=$4
                                ;;
        --local-passwd)         LOCAL_PASSWD=$4
                                ;;
        --local-repo)           LOCAL_REPO=$4
                                ;;
        -h | --help)            help
                                exit 0
                                ;;
        *)                      help
                                exit 1
                                ;;
    esac
    shift 2
done

REMOTE_USER=${REMOTE_USER:-jenkins}
REMOTE_PASSWD=${REMOTE_PASSWD:-jenkins}
LOCAL_USER=${LOCAL_USER:-admin}
LOCAL_PASSWD=${LOCAL_PASSWD:-admin123}
LOCAL_REPO=${LOCAL_REPO:-nexus3.onap.org:10001}

# Login to CICD server, pull image and push it into CICD nexus repo
/usr/bin/ssh -oStrictHostKeyChecking=no $SERVER << EOF
  set -e
  docker pull $REPO_IMAGE
  docker tag $REPO_IMAGE $SERVER/$IMAGE
  docker login -u $REMOTE_USER -p $REMOTE_PASSWD $SERVER
  docker push $SERVER/$IMAGE
  docker rmi $REPO_IMAGE
  docker rmi $SERVER/$IMAGE
EOF

if [ $? -eq 1 ]
then
  exit 1
fi

# Download image from CICD nexus repo and push it into local repo
docker pull  $SERVER/$IMAGE
docker tag $SERVER/$IMAGE $LOCAL_REPO/$IMAGE
docker login -u $LOCAL_USER -p $LOCAL_PASSWD $LOCAL_REPO
docker push $LOCAL_REPO/$IMAGE
docker rmi $SERVER/$IMAGE
docker rmi $LOCAL_REPO/$IMAGE

echo 'Done Successfully'
