#!/usr/bin/env bash

# Set type of distribution where script is running
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

# Path where will be created repository (in container)
OFFLINE_REPO_DIR=""

# Path where is stored onap_rpm.list and onap_deb.list file
PCKG_LIST_DIR=""

# Show help for using this script
help () {
cat <<EOF
Docker entrypoint script for creating RPM/DEB repository based on linux distribution where script is running

usage: create-repo.sh [-d|--directory output directory] [-l|--list input rpm/deb list directory] [-a|--additional-lists list1.list, list2.list, ...]
-h --help: Show this help
-d --directory: set path for repo directory in container
-l --list: set path where rpm or deb list is stored in container
-a --additional-lists: add additional packages lists in same directory as main package list

Both paths have to be set with shared volume between
container and host computer. Default path in container is: /tmp/
Repository will be created at: /<path>/resources/pkg/rhel/
RMP/DEB list is stored at: ./data_list/
EOF
}

# Getting input parametters
POSITIONAL=()
if [[ $# -eq 0 ]] ; then
    help # show help
    exit 0
fi
while [[ $# -gt 0 ]]
do
    case "$1" in
        -h|--help)
            # Help parametter
            help # show help
            exit
            ;;
        -d|--directory)
            # Directory parametter
            # Sets path where will be created reposity
            OFFLINE_REPO_DIR="$2"
            ;;
        -l|--list)
            # List parametter
            # Sets path where is stored onap_rpm.list or onap_deb.list file
            PCKG_LIST_DIR="$2"
            ;;
        -a|--additional-lists)
            # Array of additional packages lists
            for i in "${@:2}"
            do
                additional_lists+=("$i")
            done
            ;;
        *)
            # unknown option
            help # show help
            exit
            ;;
    esac
    shift;shift
done

# Testing if directory parametter was used
# If not variable is sets to default value:
# /tmp/repo/resources/pkg/rpm
# or
# /tmp/repo/resources/pkg/deb
if test -z "$OFFLINE_REPO_DIR"
then
    OFFLINE_REPO_DIR="/tmp/repo/"
fi

# Testing if list parametter was used
# If not variable is sets to default value /tmp/offline/data-list
if test -z "$PCKG_LIST_DIR"
then
    PCKG_LIST_DIR="/tmp/offline/data_list/"
fi

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

        # Download all packages with dependecies from all additional packages lists via apt-get to repository folder
        if ! [ ${#additional_lists[@]} -eq 0 ]; then
            for list in $additional_lists
            do
                for i in $(cat ${PCKG_LIST_DIR}$list | awk '{print $1}');do apt-get download $i -y; done
                for i in $(cat ${PCKG_LIST_DIR}$list | awk '{print $1}');
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
        if ! [ ${#additional_lists[@]} -eq 0 ]; then
            for list in $additional_lists
            do
                for i in $(cat ${PCKG_LIST_DIR}$list | awk '{print $1}');do yumdownloader --resolve --downloadonly --destdir=${OFFLINE_REPO_DIR} $i -y; done
            done
        fi

        # In repository folder create repositor
        createrepo $OFFLINE_REPO_DIR
    ;;

    *)
        echo "Unknown type of linux distribution."
        exit 1
    ;;
esac
