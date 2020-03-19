#!/usr/bin/env bash

# Set type of distribution
distro_type="$(cat /etc/*-release | grep -w "ID" | awk -F'=' '{ print $2 }' | tr -d '"')"

# Path to folder with cloned offline-installer build directory with docker_entrypoint script
volume_offline_directory="$(readlink -f $(dirname ${0}))"

# Path for directory where repository will be created
volume_repo_directory="$(pwd)"

# Path inside container with cloned offline-installer build directory
container_offline_volume="/mnt/offline/"

# Path inside container where will be created repository
container_repo_volume="/mnt/repo/"

# Show help for using this script
help () {
cat <<EOF
Script for run docker container creating DEB or RPM repository

Type of repository is created based on user input or if input is empty type of host OS

usage: create_repo.sh [-d|--destination-repository output directory] [-c|--cloned-directory input directory] [-t|--target-platform (ubuntu/rhel/centos) target platform for repository]
-h --help: Show this help
-d --destination-repository: set path where will be stored RPM packages. Default value is current directory
-c --cloned-directory: set path where is stored this script and docker-entrypoint script (offline-installer/build directory). Fill it just when you want to use different script/datalists
-t --target-platform: set target platform for repository
-a --additional-lists: add additional packages lists in same directory as main package list

If build folder from offline repository is not specified will be used default path of current folder.
EOF
}

# Get type of distribution
# Set Docker image name and version based on type of linux distribution
# Set expected directory for RPM/DEB packages
set_enviroment () {
    case "$1" in
    ubuntu)
        distro_type="ubuntu"
        docker_image="ubuntu:18.04"
        expected_dir="resources/pkg/deb"
        container_name=$1"_repo"
    ;;
    centos|rhel)
        distro_type="rhel"
        docker_image="centos:centos7.6.1810"
        expected_dir="resources/pkg/rpm"
        container_name=$1"_repo"
    ;;
    *)
        echo "Unknown type of linux distribution."
        exit 1
    ;;
    esac
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
        -t|--target-platform)
            # Repository type (rpm/deb)
            # Sets target platform for repository
            target_input="$2"
            ;;
        -a|--additional-lists)
            # Array with more packages lists
            # Add more packages lists to download
            for i in "${@:2}"
            do
                additional_lists+=("$i")
            done
            ;;
        *)
            # unknown option
            help # show help
            exit 1
            ;;
    esac
    shift;shift
done

# Check if user specified type of repository
# This settings have higher priority, then type of distribution
if ! test -z "$target_input"
then
    set_enviroment "$target_input"
else
    set_enviroment "$distro_type"
fi

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
    # with dynamic parameters
    paramArray=()
    paramArray+=(--directory ${container_repo_volume})
    paramArray+=(--list ${container_offline_volume}data_lists/)
    [[ ! ${#additional_lists[@]} -eq 0 ]] && paramArray+=(--additional-lists "${additional_lists[*]}")

    docker run -d \
               --name $container_name \
               -v ${volume_offline_directory}:${container_offline_volume} \
               -v ${volume_repo_directory}:${container_repo_volume} \
               --rm \
               --entrypoint="${container_offline_volume}docker-entrypoint.sh" \
                    -it ${docker_image} \
                    "${paramArray[@]}"
    docker logs $(docker ps --filter "name=${container_name}" --format '{{.ID}}' -a) -f
fi
