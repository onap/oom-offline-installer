#!/usr/bin/env bash

container_name="centos_repo"
# Path to folder with clonned offline-installer build directory with docker_entrypoint script
volume_oom_directory="$(readlink -f $(dirname ${0}))"
# Path for directory where repository will be created
volume_repo_directory="$(pwd)"
# Path inside container with clonned offline-installer build directory
container_oom_volume="/mnt/oom/"
# Path inside container where will be created repository
container_repo_volume="/mnt/repo/"
# Docker image name and version
docker_image="centos:centos7.6.1810"
# Expected directory for RPM packages
expected_dir="resources/pkg/rhel"

help () {
    echo -e "Script for run docker container with RPM repository\n"
    echo "-h --help: Show this help"
    echo -e "-c --clonned-directory: set path where is stored this script (offline-installer/build directory)\n"
    echo -e "-d --destinatio-repository: set path where will be stored RPM packages (/<path>/resources/pkg/rhel/)\n"
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
    key="$1"
    case $key in
        -h|--help)
            # Help parametter
            help # show help
            shift # past argument
            shift # past value
            exit 0
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
        *)
            # unknown option
            help # show help
            exit 1
            ;;
    esac
done

# Check if path contains expected path "resources/pkg/rhel"
if ! [[ "/$volume_repo_directory/" = *"/$expected_dir/"* ]]; then
    # Create repo folder if it not exists
    volume_repo_directory="$volume_repo_directory"/resources/pkg/rhel
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
               -v ${volume_oom_directory}:${container_oom_volume} \
               -v ${volume_repo_directory}:${container_repo_volume} \
               --rm \
               --entrypoint="${container_oom_volume}docker-entrypoint.sh" \
               -it ${docker_image} \
               --directory ${container_repo_volume} \
               --list ${container_oom_volume}data_lists/
fi
