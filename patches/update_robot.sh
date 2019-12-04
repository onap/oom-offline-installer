#!/usr/bin/env	bash

set -xe

NAMESPACE=$1
NETPREFIX=$2
#ROBOT_POD=`kubectl  get pods | grep robot | awk {'print $1'}`
ROBOT_HOME="/var/opt/ONAP"

# distribute example private key onap-dev
kubectl cp -n ${NAMESPACE} onap-dev.pem ${ROBOT_POD}:${ROBOT_HOME}/onap-dev.pem

# stability improvement for SRPOL lab
# there is an issue that cloudinit is randomly putting default route
# on interfaces w/o internet connectivity
# this patch assume that we are using rc3-offline-network as public network for vFW VMs
# vFW VMs are installing SW in runtime, similarly as other ONAP demo usecases
# please note that such network must be reachable from robot pod
#kubectl cp -n ${NAMESPACE} ${ROBOT_POD}:${ROBOT_HOME}/demo/heat/vFW/base_vfw.yaml base_vfw.yaml
HACK="\n            # nasty hack to bypass cloud-init issues\n            sed  -i '1i nameserver 8.8.8.8' /etc/resolv.conf\n            iface_correct=\`ip a | grep ${NETPREFIX} | awk {'print \$7'}\`\n            route add default gw ${NETPREFIX}.1 \${iface_correct}"

kubectl cp -n ${NAMESPACE} ${ROBOT_POD}:${ROBOT_HOME}/demo/heat/vFW/base_vfw.yaml base_vfw.yaml
sed -i -e "/#!\/bin\/bash/a\ ${HACK}" base_vfw.yaml
kubectl cp -n ${NAMESPACE} base_vfw.yaml ${ROBOT_POD}:${ROBOT_HOME}/demo/heat/vFW/base_vfw.yaml
