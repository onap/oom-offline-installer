#!/bin/bash

container_name="centos_repo"
# Path to folder with clonned offline-installer gerrit and docker_entrypoint script
volume_directory="."
# Path inside container
container_volume="/mnt/"
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
    echo "
Script for run docker container with RPM repository

-h --help: Show this help
-d --directory: set path with of build folder from offline-installer where is this script

If build folder from offline repository is not specified will be used default path of current folder.
"
    shift # past argument
    shift # past value
    exit
    ;;
    -d|--directory)
    # Directory parametter
    # Sets path where is clonned offline-installer git
    volume_directory="$2"
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done


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
               -v ${volume_directory}:${container_volume} \
               --entrypoint="${container_volume}docker-entrypoint.sh" \
               -it ${docker_image} \
               --rm \
               --directory ${container_volume}repo \
               --list ${container_volume}data_lists/ 
fi
