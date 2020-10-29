#!/usr/bin/env bash

set -eo pipefail

# Set distribution family
distro_type=$(cat /etc/*-release | grep -w "ID" | awk -F'=' '{ print $2 }' | tr -d '"')
case "$distro_type" in
        ubuntu)
                distro_type="ubuntu"
        ;;
        rhel|centos)
                distro_type="rhel"
        ;;
        *)
                echo "Unknown type of linux distribution."
                exit 1
        ;;
esac

# Target path for created repository
OFFLINE_REPO_DIR=""

# Path to directory containing onap_rpm.list and onap_deb.list files
PCKG_LIST_DIR=""

# Path to additional packages lists
ADD_LIST_DIR=""

# Show help
help () {
cat <<EOF
Docker entrypoint script for creating RPM/DEB repository based on container platform type

usage: create-repo.sh [OPTION]...

  -d | --directory              target repository path
  -l | --list                   input rpm/deb list directory
  -a | --additional-list        additional packages list; can be used multiple times
  -p | --packages-lists-path    other additional packages lists
  -h | --help                   show this help

Both paths have to be set with shared volume between
container and the host. Default path in container is: /tmp/
Repository will be created at: /<path>/resources/pkg/rhel/
RMP/DEB list is stored at: ./data_list/
EOF
}

# Getting input parameters
if [[ $# -eq 0 ]] ; then
    help # show help
    exit 0
fi
while [[ $# -gt 0 ]]
do
    case "$1" in
        -h|--help)
            # Help parameter
            help # show help
            exit
            ;;
        -d|--directory)
            # Directory parameter
            # Set target reposity path
            OFFLINE_REPO_DIR="$2"
            ;;
        -l|--list)
            # List parameter
            # Set path containing onap_rpm.list or onap_deb.list file
            PCKG_LIST_DIR="$2"
            ;;
        -p|--packages-lists-path)
            # Path parameter
            # Set path for additional packages lists
            ADD_LIST_DIR="$2"
            ;;
        -a|--additional-list)
            # Array of additional packages lists
            ADDITIONAL_LISTS+=("$2")
            ;;
        *)
            # unknown option
            help # show help
            exit
            ;;
    esac
    shift;shift
done

# Testing if directory parameter was used
# If not variable is set to /tmp/repo by default
if test -z "$OFFLINE_REPO_DIR"
then
    OFFLINE_REPO_DIR="/tmp/repo/"
fi

# Testing if list parameter was used
# If not variable is set to default value /tmp/offline/data-list
if test -z "$PCKG_LIST_DIR"
then
    PCKG_LIST_DIR="/tmp/offline/data_list/"
fi

# Testing if additional packages list parameter was used
# If not variable is set to default value /tmp/additional-lists
if test -z "$PCKG_LIST_DIR"
then
    PCKG_LIST_DIR="/tmp/additional-lists/"
fi

# Clean target repo dir for idempotency
rm -rf ${OFFLINE_REPO_DIR}/*

case "$distro_type" in
    ubuntu)
        # Change current working dir
        pushd $OFFLINE_REPO_DIR

        # Install dpkg-deb package for create repository in folder
        # Install software-properties-common to get add-apt-repository command
        # Install apt-transport-https, ca-certificates, curl and gnupg-agent allowing apt to use a repository over HTTPS
        apt-get update -y
        apt-get install dpkg-dev apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y

        # Add Docker's official GPG key:
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        apt-key fingerprint 0EBFCD88

        # Add docker repository
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

        # Temp fix of known bug
        # https://bugs.launchpad.net/ubuntu/+source/aptitude/+bug/1543280
        chown _apt $OFFLINE_REPO_DIR

        # Download all packages from onap_deb.list via apt-get to repository folder
        for i in $(cat ${PCKG_LIST_DIR}onap_deb.list | awk '{print $1}');do apt-get download $i -y; done
        for i in $(cat ${PCKG_LIST_DIR}onap_deb.list | awk '{print $1}');
                    do
                    for depends in $(apt-cache depends $i | grep -E 'Depends' | cut -d ':' -f 2,3 | sed -e s/'<'/''/ -e s/'>'/''/);
                        do apt-get download $depends -y;
                    done;
                done

        # Download all packages with dependencies from all additional packages lists via apt-get to repository folder
        if ! [ ${#ADDITIONAL_LISTS[@]} -eq 0 ]; then
            for list in ${ADDITIONAL_LISTS[@]}
            do
                for i in $(cat ${ADD_LIST_DIR}$list | awk '{print $1}');do apt-get download $i -y; done
                for i in $(cat ${ADD_LIST_DIR}$list | awk '{print $1}');
                    do
                    for depends in $(apt-cache depends $i | grep -E 'Depends' | cut -d ':' -f 2,3 | sed -e s/'<'/''/ -e s/'>'/''/);
                        do apt-get download $depends -y;
                    done;
                done
            done
        fi

        # In repository folder create gz package with deb packages
        dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    ;;

    rhel)
        # Install createrepo package for create repository in folder,
        # yum-utils due to yum-config-manager for adding docker repository
        # and epel-release for additional packages (like jq etc.)
        yum install createrepo yum-utils epel-release -y

        # Add official docker repository
        yum-config-manager --add-repo=https://download.docker.com/linux/centos/7/x86_64/stable/

        # Download all packages from onap_rpm.list via yumdownloader to repository folder
        for i in $(cat ${PCKG_LIST_DIR}onap_rpm.list | awk '{print $1}');do yumdownloader --resolve --downloadonly --destdir=${OFFLINE_REPO_DIR} $i -y; done

        # Download all packages from all additional packages lists via apt-get to repository folder
        if ! [ ${#ADDITIONAL_LISTS[@]} -eq 0 ]; then
            for list in ${ADDITIONAL_LISTS[@]}
            do
                for i in $(cat ${ADD_LIST_DIR}$list | awk '{print $1}');do yumdownloader --resolve --downloadonly --destdir=${OFFLINE_REPO_DIR} $i -y; done
            done
        fi

        # Create repository
        createrepo $OFFLINE_REPO_DIR
    ;;

    *)
        echo "Unknown type of linux distribution."
        exit 1
    ;;
esac
