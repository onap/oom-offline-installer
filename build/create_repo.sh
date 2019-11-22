#!/usr/bin/env bash

# Get type of distribution
# Set Docker image name and version based on type of linux distribution
# Set expected directory for RPM/DEB packages
case "$(cat /etc/*-release | grep -w "ID" | awk -F'=' '{ print $2 }' | tr -d '"')" in
    ubuntu)
        distro_type="ubuntu"
        docker_image="ubuntu:18.04"
        expected_dir="resources/pkg/deb"
    ;;
    centos|rhel)
        distro_type="rhel"
        docker_image="centos:centos7.6.1810"
        expected_dir="resources/pkg/rpm"
    ;;
    *)
        echo "Unknown type of linux distribution."
        exit 1
    ;;
esac

# Set name of container based on type of distribution
container_name="${distro_type}_repo"

# Path to folder with cloned offline-installer build directory with docker_entrypoint script
volume_offline_directory="$(readlink -f $(dirname ${0}))"

# Path for directory where repository will be created
volume_repo_directory="$(pwd)"

# Path inside container with cloned offline-installer build directory
container_offline_volume="/mnt/offline/"

# Path inside container where will be created repository
container_repo_volume="/mnt/repo/"

help () {
    echo "Script for run docker container with DEB or RPM repository based on host OS"
    echo "usage: create_repo.sh [-d|--destination-repository output directory] [-c|--cloned-directory input directory]"
    echo "-h --help: Show this help"
    echo "-d --destination-repository: set path where will be stored RPM packages. Default value is current directory"
    echo "-c --cloned-directory: set path where is stored this script and docker-entrypoint script (offline-installer/build directory). Fill it just when you want to use different script/datalists"
    echo "If build folder from offline repository is not specified will be used default path of current folder."
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
            exit 0
            ;;
	-c|--cloned-directory)
	    # Directory parametter
            # Sets path where is cloned offline-installer build directory
            volume_offline_directory="$2"
            ;;
        -d|--destination-repository)
            # Repository direcotry parametter
            # Sets path where will be repository created
            volume_repo_directory="$2"
            ;;
        *)
            # unknown option
            help # show help
            exit 1
            ;;
    esac
    shift;shift
done

# Check if path contains expected path:
# "resources/pkg/rpm" for Rhel/CentOS or
# "resources/pkg/deb" for Ubuntu/Debian
if ! [[ "/$volume_repo_directory/" = *"/$expected_dir/"* ]]; then
    # Create repo folder if it not exists
    case "$distro_type" in
        ubuntu)
            volume_repo_directory="$volume_repo_directory"/resources/pkg/deb
        ;;
        rhel)
            volume_repo_directory="$volume_repo_directory"/resources/pkg/rhel
        ;;
    esac
    [ ! -d "$volume_repo_directory" ] && mkdir -p $volume_repo_directory
fi

#Check if container "centos-repo" is running
if [ ! "$(docker ps -q -f name=$container_name)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=$container_name)" ]; then
        # cleanup
        docker rm $container_name
    fi
    # run repo container
    # name of container $container_name
    # docker entrypoint script from mounted volume
    #
    docker run -d \
               --name $container_name \
               -v ${volume_offline_directory}:${container_offline_volume} \
               -v ${volume_repo_directory}:${container_repo_volume} \
               --rm \
               --entrypoint="${container_offline_volume}docker-entrypoint.sh" \
               -it ${docker_image} \
               --directory ${container_repo_volume} \
               --list ${container_offline_volume}data_lists/
    docker logs $(docker ps --filter "name=${container_name}" --format '{{.ID}}' -a) -f
fi
