#!/bin/sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#
# globals and defaults
#

NAMESPACE=
OVERRIDES=
HELM_CHART_RELEASE_NAME=
VOLUME_STORAGE=
HELM_TIMEOUT=3600

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
           [-t|--timeout <secs>]
           [(-c|--component <component release name>)...]

    Namespace argument and at least one override file are
    mandatory for this script to execute. Also you must provide
    path to the storage or explicitly request to not delete file
    storage of the component.

    Storage should be directory where persistent volume resides.
    It will work only if component created a persistent volume
    with the same filename as its release name. Otherwise
    no effect.

    Eg.:
        ${CMD} -n onap -f /some/override1.yml -s /dockerdata-nfs

    CAUTION: filename of an override file cannot contain whitespace!
    This is actually helm issue (ver 2.x) which does not handle such
    files. So I dropped the more complicated version of this script
    when there is no reason to support something on what will helm
    choke anyway.

    Timeout set the waiting time for helm deploy per component.

    Component reference to release name of the chart which you
    want to redeploy excplicitly - otherwise ALL failed
    components will be redeployed.

    You can target more than one component at once - just use
    the argument multiple times.
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
    kubectl get pods -n ${NAMESPACE} \
        --show-labels=true \
        --include-uninitialized=true \
        --field-selector='status.phase==Failed' \
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
    msg "Undeploy helm release name ${1}..."
    helm undeploy ${1} --purge
}

# arg: <job name>
delete_job()
{
    kubectl delete job -n ${NAMESPACE} \
        --cascade=true \
        --now=true \
        --include-uninitialized=true \
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
            --no-headers=true | grep "$_release"
    } | sort -u | while read -r _name _rest ; do
            kubectl delete ${_resource} -n ${NAMESPACE} \
                --cascade=true \
                --now=true \
                --include-uninitialized=true \
                --wait=true \
                ${_name}

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
        msg "Persistent volume data deletion in directory: ${VOLUME_STORAGE}"

        _node=$(kubectl get nodes \
            --selector=node-role.kubernetes.io/worker \
            -o wide \
            --no-headers=true | \
            awk '{print $6}' | head -n 1)

        if [ -z "$_node" ] ; then
            error "Could not list kubernetes nodes - SKIPPING DELETION"
        else
            msg "Delete directory ${VOLUME_STORAGE}/${1} on $_node"
            ssh -T $_node <<EOF
rm -rf "${VOLUME_STORAGE}/${1}"
EOF
        fi
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
                    state=component
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


#
# main
#

# if a helm chart release name was given then just redeploy said component and quit
if [ -n "$HELM_CHART_RELEASE_NAME" ] ; then
    msg "Explicitly asked for component redeploy: ${HELM_CHART_RELEASE_NAME}"
    _COMPONENTS="$HELM_CHART_RELEASE_NAME"
else
    msg "Delete successfully completed jobs..."
    clean_jobs

    msg "Find failed components..."
    _COMPONENTS=$(get_failed_labels)
fi

for _component in ${_COMPONENTS} ; do
    msg "Redeploy component: ${_component}"
    redeploy_component ${_component}
done

# TODO: this is suboptimal - find a way how to deploy only the affected component...
msg "Redeploy onap..."
msg helm deploy onap local/onap --namespace ${NAMESPACE} ${OVERRIDES} --timeout ${HELM_TIMEOUT}
helm deploy onap local/onap --namespace ${NAMESPACE} ${OVERRIDES} --timeout ${HELM_TIMEOUT}

exit $?

