#!/usr/bin/env bash

set -x

container_name="centos_repo"
# Path to folder with clonned offline-installer build directory with docker_entrypoint script
volume_oom_directory="$(pwd)"
# Path for directory where repository will be created
volume_repo_directory="$(pwd)"
# Path inside container with clonned offline-installer build directory
container_oom_volume="/mnt/oom/"
# Path inside container where will be created repository
container_repo_volume="/mnt/repo/"
# Docker image name and version
docker_image="centos:centos7.6.1810"

# Getting input parametters
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -h|--help)
            # Help parametter
            echo -e "Script for run docker container with RPM repository\n"
            echo "-h --help: Show this help"
            echo -e "-d --directory: set root path with offline-installer directory and repository directory for RPM packages\n"
            echo "If build folder from offline repository is not specified will be used default path of current folder."
            shift # past argument
            shift # past value
            exit
            ;;
        -c|--clonned-directory)
            # Directory parametter
            # Sets path where is clonned offline-installer build directory
            volume_oom_directory="$2"
            shift # past argument
            shift # past value
            ;;
        -d|--destination-repository)
            # Repository direcotry parametter
            # Sets path where will be repository created
            volume_repo_directory="$2"
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

ls .
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
               -v ${volume_oom_directory}:${container_oom_volume} \
               -v ${volume_repo_directory}:${container_repo_volume} \
               --entrypoint="${container_oom_volume}offline-installer/build/docker-entrypoint.sh" \
               -it ${docker_image} \
               --rm \
               --directory ${container_repo_volume}resources/pkg/rhel/ \
               --list ${container_oom_volume}offline-installer/build/data_lists/
fi
