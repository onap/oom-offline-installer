#!/usr/bin/env bash

# Path where will be created repository (in container)
OFFLINE_REPO_DIR=""

# Path where is stored onap_rpm.list file
RPM_LIST_DIR=""

help () {
    echo -e "Docker entrypoint script for creating RPM repository\n"
    echo "usage: create-repo.sh [-d|--directory output directory] [-l|--list input rpm list directory]"
    echo "-h --help: Show this help"
    echo "-d --directory: set path for repo directory in container"
    echo -e "-l --list: set path where rpm list is stored in container\n"
    echo "Both paths have to be set with shared volume between"
    echo "container and host computer. Default path in container is: /tmp/"
    echo "Repository will be created at: /<path>/resources/pkg/rpm/"
    echo "RMP list is stored at: ./data_list/"
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
            # Sets path where is stored onap_rpm.list file
            RPM_LIST_DIR="$2"
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
# If not variable is sets to default value /tmp/repo/resources/pkg/rpm
if test -z "$OFFLINE_REPO_DIR"
then
    OFFLINE_REPO_DIR="/tmp/repo/"
fi

# Testing if list parametter was used
# If not variable is sets to default value /tmp/offline/data-list
if test -z "$RPM_LIST_DIR"
then
    RPM_LIST_DIR="/tmp/offline/data_list/"

fi

# Install createrepo package for create repository in folder
# and yum-utils due to yum-config-manager for adding docker repository
yum install createrepo yum-utils -y

# Add official docker repository
yum-config-manager --add-repo=https://download.docker.com/linux/centos/7/x86_64/stable/

# Download all packages from onap_rpm.list via yumdownloader to repository folder
for i in $(cat ${RPM_LIST_DIR}onap_rpm.list | awk '{print $1}');do yumdownloader --resolve --downloadonly --destdir=${OFFLINE_REPO_DIR} $i -y; done

# In repository folder create repository
createrepo $OFFLINE_REPO_DIR
