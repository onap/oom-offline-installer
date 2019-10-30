#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#
# globals and defaults
#

NAMESPACE=
OVERRIDES=
HELM_CHART_RELEASE_NAME=
HELM_DELETE_ALL=
HELM_SKIP_DEPLOY=
VOLUME_STORAGE=
HELM_TIMEOUT=3600
RELEASE_PREFIX=onap

#
# control variables
#

CMD=$(basename "$0")
COLOR_ON_RED='\033[0;31;1m'
COLOR_ON_GREEN='\033[0;32;1m'
COLOR_OFF='\033[0m'


#
# functions
#

help()
{
cat <<EOF
${CMD} - simple tool for fixing onap helm deployment

DESCRIPTION
    This script does nothing smart or special it just tries to
    redeploy onap component. It can fix only problems related to
    race conditions or timeouts. Nothing else. It will not fix
    broken ONAP - there is no such ambition - that effort should
    be directed in the upstream.

USAGE
    ${CMD} -h|--help
        This help

    ${CMD} -n|--namespace <namespace>
           (-f|--file <override>)...
           (-s|--storage <directory>)|--no-storage-deletion
           [-p|--release-prefix <release prefix>]
           [-t|--timeout <secs>]
           [(-c|--component <component release name>)...|
            (-D|--delete-all)]
           [-C|--clean-only]

    Usage 1 (simple heuristics - redeploy failed components):
        ${CMD} -n onap -f /some/override1.yml -s /dockerdata-nfs

    Usage 2 (redeploy ONLY explicit listed components):
        ${CMD} -n onap -f /some/override1.yml -s /dockerdata-nfs \\
               -c onap-aaf -c onap-sdc -c onap-portal

    Usage 3 (delete EVERYTHING and redeploy):
        ${CMD} -n onap -f /some/override1.yml -s /dockerdata-nfs \\
               --delete-all

    Usage 4 (just clean - do not redeploy)
        ${CMD} -n onap -f /some/override1.yml -s /dockerdata-nfs \\
               --delete-all --clean-only

    Namespace argument and at least one override file are mandatory
    for this script to execute. Also you must provide path to the
    storage or explicitly request to not delete file storage of the
    component.

    Storage should be directory where persistent volume resides. It
    will work only if component created a persistent volume with the
    same filename as its release name. Otherwise no effect. The
    exception is when '--delete-all' is used - in that case all
    content of the storage is deleted (because ONAP is not consistent
    with the volume directory names - eg.: sdnc).

    CAUTION 1: filename of an override file cannot contain whitespace!
    This is actually helm/onap deploy plugin issue which does not
    handle such files. So I dropped the more complicated version of
    this script when there is no reason to support something on what
    will helm deploy choke anyway.

    '--prefix' option is helm release argument - it is actually prefix
    when you list the helm releases - helm is little confusing here.

    CAUTION 2: By default release prefix is 'onap' - if you deployed
    release 'onap' and now run this script with different prefix then
    it will skip all 'onap-*' components and will deploy a new release
    with new prefix - BEWARE TO USE PROPER RELEASE PREFIX!

    Timeout set the waiting time for helm deploy per component.

    '--component' references to release name of the chart which you
    want to redeploy excplicitly - otherwise 'ALL FAILED' components
    will be redeployed. You can target more than one component at once
    - just use the argument multiple times.

    Component option is mutually exclusive with the '--delete-all'
    which will delete all components - healthy or not. Actually it will
    delete the whole NAMESPACE and everything in it.

    '--clean-only' can be used with any usage: heuristics, explicit
    component list or with '--delete-all'. It basically just skips the
    last step - the actual redeploy.
EOF
}

msg()
{
    echo -e "${COLOR_ON_GREEN}INFO: $@ ${COLOR_OFF}"
}

error()
{
    echo -e "${COLOR_ON_RED}ERROR: $@ ${COLOR_OFF}"
}

# remove all successfully completed jobs
clean_jobs()
{
    kubectl get jobs -n ${NAMESPACE} \
        --ignore-not-found=true \
        --no-headers=true | \
        while read -r _job _completion _duration _age ; do
            _done=$(echo ${_completion} | awk 'BEGIN {FS="/";} {print $1;}')
            _desired=$(echo ${_completion} | awk 'BEGIN {FS="/";} {print $2;}')
            if [ "$_desired" -eq "$_done" ] ; then
                delete_job "$_job"
            fi
        done
}

get_failed_labels()
{
    get_labels 'status.phase==Failed'
}

# arg: [optional: selector]
get_labels()
{
    if [ -n "$1" ] ; then
        _selector="--field-selector=${1}"
    else
        _selector=
    fi

    kubectl get pods -n ${NAMESPACE} \
        --show-labels=true \
        ${_selector} \
        --ignore-not-found=true \
        --no-headers=true | \
        while read -r _pod _ready _status _restart _age _labels ; do
            [ -z "$_labels" ] && break
            for _label in $(echo "$_labels" | tr ',' ' ') ; do
                case "$_label" in
                    release=*)
                        _label=$(echo "$_label" | sed 's/release=//')
                        echo "$_label"
                        ;;
                esac
            done
        done | sort -u
}

# arg: <release name>
helm_undeploy()
{
    msg "Undeploy helm release name: ${1}"
    helm undeploy ${1} --purge
}

# arg: <job name>
delete_job()
{
    kubectl delete job -n ${NAMESPACE} \
        --cascade=true \
        --now=true \
        --wait=true \
        ${1}

    # wait for job to be deleted
    _output=start
    while [ -n "$_output" ] && sleep 1 ; do
        _output=$(kubectl get pods -n ${NAMESPACE} \
            --ignore-not-found=true \
            --no-headers=true \
            --selector="job-name=${1}")
    done
}

# arg: <resource> <release name>
delete_resource()
{
    _resource="$1"
    _release="$2"

    msg "Delete ${_resource} for ${_release}..."
    {
        kubectl get ${_resource} -n ${NAMESPACE} \
            --ignore-not-found=true \
            --selector="release=${_release}" \
            --no-headers=true

        # this is due to missing "release" label in some pods
        # grep for the rescue...
        kubectl get ${_resource} -n ${NAMESPACE} \
            --no-headers=true | grep "^${_release}"
    } | awk '{print $1}' | sort -u | while read -r _name _rest ; do
            echo "Deleting '${_name}'"
            kubectl delete ${_resource} -n ${NAMESPACE} \
                --cascade=true \
                --now=true \
                --wait=true \
                ${_name} \
                2>&1 | grep -iv 'not[[:space:]]*found'

            # wait for resource to be deleted
            _output=start
            while [ -n "$_output" ] && sleep 1 ; do
                _output=$(kubectl get ${_resource} -n ${NAMESPACE} \
                    --ignore-not-found=true \
                    --no-headers=true \
                    --field-selector="metadata.name=${_name}")
            done
        done
}

delete_namespace()
{
    msg "Delete the whole namespace: ${NAMESPACE}"
    kubectl delete namespace \
        --cascade=true \
        --now=true \
        --wait=true \
        "$NAMESPACE"

    # wait for namespace to be deleted
    _output=start
    while [ -n "$_output" ] && sleep 1 ; do
        _output=$(kubectl get all -n ${NAMESPACE} \
            --ignore-not-found=true \
            --no-headers=true)
    done
}

# arg: [optional: subdir]
delete_storage()
{
    _node=$(kubectl get nodes \
        --selector=node-role.kubernetes.io/worker \
        -o wide \
        --no-headers=true | \
        awk '{print $6}' | head -n 1)

    if [ -z "$_node" ] ; then
        error "Could not list kubernetes nodes - SKIPPING DELETION"
    else
        if [ -n "$1" ] ; then
            msg "Delete directory '${VOLUME_STORAGE}/${1}' on $_node"
            ssh -T $_node <<EOF
rm -rf "${VOLUME_STORAGE}/${1}"
EOF
        else
            msg "Delete directories '${VOLUME_STORAGE}/*' on $_node"
            ssh -T $_node <<EOF
find "${VOLUME_STORAGE}" -maxdepth 1 -mindepth 1 -exec rm -rf '{}' \;
EOF
        fi
    fi
}

# arg: <release name>
redeploy_component()
{
    _chart=$(echo "$1" | sed 's/[^-]*-//')
    helm_undeploy ${1}
    # TODO: does deleted secret per component break something?
    for x in jobs deployments pods pvc pv ; do
        delete_resource ${x} ${1}
    done

    if [ -n "$VOLUME_STORAGE" ] ; then
        msg "Persistent volume data deletion in directory: ${VOLUME_STORAGE}/${1}"
        delete_storage "$1"
    fi

    # TODO: until I can verify that this does the same for this component as helm deploy
    #msg "Redeployment of the component ${1}..."
    #helm install "local/${_chart}" --name ${1} --namespace ${NAMESPACE} --wait --timeout ${HELM_TIMEOUT}
}


#
# arguments
#

state=nil
arg_namespace=
arg_overrides=
arg_timeout=
arg_storage=
arg_nostorage=
arg_components=
arg_prefix=
arg_deleteall=
arg_cleanonly=
while [ -n "$1" ] ; do
    case $state in
        nil)
            case "$1" in
                -h|--help)
                    help
                    exit 0
                    ;;
                -n|--namespace)
                    state=namespace
                    ;;
                -f|--file)
                    state=override
                    ;;
                -t|--timeout)
                    state=timeout
                    ;;
                -s|--storage)
                    state=storage
                    ;;
                --no-storage-deletion)
                    if [ -n "$arg_storage" ] ; then
                        error "Usage of storage argument together with no storage deletion option!"
                        exit 1
                    elif [ -z "$arg_nostorage" ] ; then
                        arg_nostorage=nostorage
                    else
                        error "Duplicit argument for no storage option! (IGNORING)"
                    fi
                    ;;
                -c|--component)
                    if [ -n "$arg_deleteall" ] ; then
                        error "'Delete all components' used already - argument mismatch"
                        exit 1
                    fi
                    state=component
                    ;;
                -D|--delete-all)
                    if [ -n "$arg_components" ] ; then
                        error "Explicit component(s) provided already - argument mismatch"
                        exit 1
                    elif [ -z "$arg_deleteall" ] ; then
                        arg_deleteall=deleteall
                    else
                        error "Duplicit argument for 'delete all' option! (IGNORING)"
                    fi
                    ;;
                -p|--prefix)
                    state=prefix
                    ;;
                -C|--clean-only)
                    if [ -z "$arg_cleanonly" ] ; then
                        arg_cleanonly=cleanonly
                    else
                        error "Duplicit argument for 'clean only' option! (IGNORING)"
                    fi
                    ;;
                *)
                    error "Unknown parameter: $1"
                    exit 1
                    ;;
            esac
            ;;
        namespace)
            if [ -z "$arg_namespace" ] ; then
                arg_namespace="$1"
                state=nil
            else
                error "Duplicit argument for namespace!"
                exit 1
            fi
            ;;
        override)
            if ! [ -f "$1" ] ; then
                error "Wrong filename for override file: $1"
                exit 1
            fi
            arg_overrides="${arg_overrides} -f $1"
            state=nil
            ;;
        component)
            arg_components="${arg_components} $1"
            state=nil
            ;;
        prefix)
            if [ -z "$arg_prefix" ] ; then
                arg_prefix="$1"
                state=nil
            else
                error "Duplicit argument for release prefix!"
                exit 1
            fi
            ;;
        timeout)
            if [ -z "$arg_timeout" ] ; then
                if ! echo "$1" | grep -q '^[0-9]\+$' ; then
                    error "Timeout must be an integer: $1"
                    exit 1
                fi
                arg_timeout="$1"
                state=nil
            else
                error "Duplicit argument for timeout!"
                exit 1
            fi
            ;;
        storage)
            if [ -n "$arg_nostorage" ] ; then
                error "Usage of storage argument together with no storage deletion option!"
                exit 1
            elif [ -z "$arg_storage" ] ; then
                arg_storage="$1"
                state=nil
            else
                error "Duplicit argument for storage!"
                exit 1
            fi
            ;;
    esac
    shift
done

# sanity check
if [ -z "$arg_namespace" ] ; then
    error "Missing namespace"
    help
    exit 1
else
    NAMESPACE="$arg_namespace"
fi

if [ -z "$arg_overrides" ] ; then
    error "Missing override file(s)"
    help
    exit 1
else
    OVERRIDES="$arg_overrides"
fi

if [ -n "$arg_prefix" ] ; then
    RELEASE_PREFIX="$arg_prefix"
fi

if [ -n "$arg_timeout" ] ; then
    HELM_TIMEOUT="$arg_timeout"
fi

if [ -n "$arg_storage" ] ; then
    VOLUME_STORAGE="$arg_storage"
elif [ -z "$arg_nostorage" ] ; then
    error "Missing storage argument! If it is intended then use '--no-storage-deletion' option"
    exit 1
fi

if [ -n "$arg_components" ] ; then
    HELM_CHART_RELEASE_NAME="$arg_components"
fi

if [ -n "$arg_deleteall" ] ; then
    HELM_DELETE_ALL=yes
fi

if [ -n "$arg_cleanonly" ] ; then
    HELM_SKIP_DEPLOY=yes
fi


#
# main
#

# if --delete-all is used then redeploy all components (the current namespace is deleted)
if [ -n "$HELM_DELETE_ALL" ] ; then
    # undeploy helm release (prefix)
    helm_undeploy "$RELEASE_PREFIX"

    # we will delete the whole namespace
    delete_namespace

    if [ -n "$VOLUME_STORAGE" ] ; then
        delete_storage
    fi
# delete and redeploy explicit or failed components...
else
    # if a helm chart release name was given then just redeploy said component and quit
    if [ -n "$HELM_CHART_RELEASE_NAME" ] ; then
        msg "Explicitly asked for component redeploy: ${HELM_CHART_RELEASE_NAME}"
        _COMPONENTS="$HELM_CHART_RELEASE_NAME"
    # simple heuristics: redeploy only failed components
    else
        msg "Delete successfully completed jobs..."
        clean_jobs

        msg "Find failed components..."
        _COMPONENTS=$(get_failed_labels)
    fi

    for _component in ${_COMPONENTS} ; do
        if echo "$_component" | grep -q "^${RELEASE_PREFIX}-" ; then
            msg "Redeploy component: ${_component}"
            redeploy_component ${_component}
        else
            error "Component release name '${_component}' does not match release prefix: ${RELEASE_PREFIX} (SKIP)"
        fi
    done
fi

if [ -z "$HELM_SKIP_DEPLOY" ] ; then
    # TODO: this is suboptimal - find a way how to deploy only the affected component...
    msg "Redeploy onap..."
    msg helm deploy ${RELEASE_PREFIX} local/onap --namespace ${NAMESPACE} ${OVERRIDES} --timeout ${HELM_TIMEOUT}
    helm deploy ${RELEASE_PREFIX} local/onap --namespace ${NAMESPACE} ${OVERRIDES} --timeout ${HELM_TIMEOUT}
else
    msg "Clean only option used: Skipping redeploy..."
fi

msg DONE

exit $?

