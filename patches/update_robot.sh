#!/usr/bin/env	bash

set -xe

ROBOT_POD=`kubectl  get pods | grep robot | awk {'print $1'}`
ROBOT_HOME="/var/opt/ONAP"

# distribute example private key onap-dev
kubectl cp onap-dev.pem ${ROBOT_POD}:${ROBOT_HOME}/onap-dev.pem

# stability improvement for SRPOL lab
# there is an issue that cloudinit is randomly putting default route
# on interfaces w/o internet connectivity
# this patch assume that we are using rc3-offline-network as public network for vFW VMs
# vFW VMs are installing SW in runtime, similarly as other ONAP demo usecases
# please note that such network must be reachable from robot pod
kubectl cp base_vfw.yaml ${ROBOT_POD}:${ROBOT_HOME}/demo/heat/vFW/base_vfw.yaml
