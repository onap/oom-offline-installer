#!/usr/bin/env	bash

set -xe

DROOLS_POD=`kubectl -n onap get pods | grep drools | awk {'print $1'}`
DST_BASE="/home/policy/.m2/repository/org/onap"

# WA to clean wrong _remote.repositories
# this/original version of files will prevent maven to find missing dependencies
# its not an issue in online lab and those files are updated when poms are collected from internet
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f $DST_BASE/policy/drools-applications/controlloop/common/common/1.5.3/_remote.repositories"
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f $DST_BASE/policy/drools-applications/controlloop/common/controller-usecases/1.5.3/_remote.repositories"
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f $DST_BASE/policy/drools-applications/controlloop/common/database/1.5.3/_remote.repositories"
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f $DST_BASE/policy/drools-applications/controlloop/common/eventmanager/1.5.3/_remote.repositories"
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f $DST_BASE/policy/drools-applications/controlloop/common/guard/1.5.3/_remote.repositories"
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f $DST_BASE/policy/drools-applications/controlloop/controlloop/1.5.3/_remote.repositories"
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f $DST_BASE/policy/drools-applications/drools-applications/1.5.3/_remote.repositories"

# this part is for patching POLICY-2191

patch_pom() {
    pom_name=$1
    dst_path=$2

    kubectl exec -it ${DROOLS_POD} -n onap -- bash -c "rm -f ${dst_path}/_remote.repositories;mkdir -p ${dst_path}"
    kubectl -n onap cp ./POLICY-2191/${pom_name} ${DROOLS_POD}:${dst_path}/${pom_name}
    kubectl -n onap cp ./POLICY-2191/${pom_name}.sha1 ${DROOLS_POD}:${dst_path}/${pom_name}.sha1
}

# patch 48 files in drools
patch_pom aaf-auth-client-2.1.2.pom ${DST_BASE}/aaf/authz/aaf-auth-client/2.1.2
patch_pom aaf-cadi-aaf-2.1.2.pom ${DST_BASE}/aaf/authz/aaf-cadi-aaf/2.1.2
patch_pom aaf-cadi-client-2.1.2.pom ${DST_BASE}/aaf/authz/aaf-cadi-client/2.1.2
patch_pom aaf-cadi-core-2.1.2.pom ${DST_BASE}/aaf/authz/aaf-cadi-core/2.1.2
patch_pom aaf-misc-env-2.1.2.pom ${DST_BASE}/aaf/authz/aaf-misc-env/2.1.2
patch_pom aaf-misc-rosetta-2.1.2.pom ${DST_BASE}/aaf/authz/aaf-misc-rosetta/2.1.2
patch_pom cadiparent-2.1.2.pom ${DST_BASE}/aaf/authz/cadiparent/2.1.2
patch_pom miscparent-2.1.2.pom ${DST_BASE}/aaf/authz/miscparent/2.1.2
patch_pom parent-2.1.2.pom ${DST_BASE}/aaf/authz/parent/2.1.2
patch_pom dmaapClient-1.1.9.pom ${DST_BASE}/dmaap/messagerouter/dmaapclient/dmaapClient/1.1.9
patch_pom dependencies-1.2.1.pom ${DST_BASE}/oparent/dependencies/1.2.1
patch_pom oparent-1.2.1.pom ${DST_BASE}/oparent/oparent/1.2.1
patch_pom version-1.2.1.pom ${DST_BASE}/oparent/version/1.2.1
patch_pom common-parameters-1.5.2.pom ${DST_BASE}/policy/common/common-parameters/1.5.2
patch_pom policy-endpoints-1.5.2.pom ${DST_BASE}/policy/common/policy-endpoints/1.5.2
patch_pom drools-pdp-1.5.2.pom ${DST_BASE}/policy/drools-pdp/drools-pdp/1.5.2
patch_pom policy-core-1.5.2.pom ${DST_BASE}/policy/drools-pdp/policy-core/1.5.2
patch_pom policy-management-1.5.2.pom ${DST_BASE}/policy/drools-pdp/policy-management/1.5.2
patch_pom policy-utils-1.5.2.pom ${DST_BASE}/policy/drools-pdp/policy-utils/1.5.2
patch_pom policy-models-base-2.1.3.pom ${DST_BASE}/policy/models/policy-models-base/2.1.3
patch_pom policy-models-dao-2.1.3.pom ${DST_BASE}/policy/models/policy-models-dao/2.1.3
patch_pom policy-models-examples-2.1.3.pom ${DST_BASE}/policy/models/policy-models-examples/2.1.3
patch_pom policy-models-pdp-2.1.3.pom ${DST_BASE}/policy/models/policy-models-pdp/2.1.3
patch_pom policy-models-tosca-2.1.3.pom ${DST_BASE}/policy/models/policy-models-tosca/2.1.3/

# restart policy
kubectl exec -it ${DROOLS_POD} -n onap -- bash -c '/opt/app/policy/bin/policy stop;/opt/app/policy/bin/policy start'
