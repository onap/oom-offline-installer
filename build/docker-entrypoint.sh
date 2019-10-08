#!/usr/bin/env bash

# Path where will be created repository (in container)
OOM_REPO_DIR=""

# Path where is stored onap_rpm.list file
RPM_LIST_DIR=""

# Getting input parametters
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -h|--help)
            # Help parametter
            echo -e "Docker entrypoint script for creating RPM repository\n"
            echo "-h --help: Show this help"
            echo "-d --directory: set path for repo directory in container"
            echo -e "-l --list: set path where rpm list is stored in container\n"
            echo "Both paths have to be set with shared volume between"
            echo "container and host computer. Default path in container is: /tmp/"
            echo "Repository will be created at: /<path>/resources/pkg/rhel/"
            echo "RMP list is stored at: /<path>/offline-installer/build/data_list/"
            shift # past argument
            shift # past value
            exit
            ;;
        -d|--directory)
            # Directory parametter
            # Sets path where will be created reposity
            OOM_REPO_DIR="$2"
            shift # past argument
            shift # past value
            ;;
        -l|--list)
            # List parametter
            # Sets path where is stored onap_rpm.list file
            RPM_LIST_DIR="$2"
            shift # past argument
            shift # past value
            ;;
        --default)
            DEFAULT=YES
            shift # past argument
            ;;
        *) 
            # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

# Testing if directory parametter was used
# If not variable is sets to default value /tmp/resources/pkg/rhel
if test -z "$OOM_REPO_DIR"
then
    OOM_REPO_DIR="/tmp/resources/pkg/rhel"
fi

# Testing if list parametter was used
# If not variable is sets to default value /tmp/data-list
if test -z "$RPM_LIST_DIR"
then
    RPM_LIST_DIR="/tmp/offline-installer/build/data_list/"

fi

# Create repo folder
mkdir $OOM_REPO_DIR -p

# Install createrepo package for create repository in folder
# and yum-utils due to yum-config-manager for adding docker repository
yum install createrepo yum-utils -y

# Add official docker repository
yum-config-manager --add-repo=https://download.docker.com/linux/centos/7/x86_64/stable/

# Download all packages from onap_rpm.list via yumdownloader to repository folder
for i in $(cat ${RPM_LIST_DIR}onap_rpm.list | awk '{print $1}');do yumdownloader --resolve --downloadonly --destdir=${OOM_REPO_DIR} $i -y; done

# In repository folder create repository
createrepo $OOM_REPO_DIR
