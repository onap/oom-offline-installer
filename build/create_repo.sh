#!/usr/bin/env bash

# Set distribution type
distro_type="$(cat /etc/*-release | grep -w "ID" | awk -F'=' '{ print $2 }' | tr -d '"')"

# Path to cloned offline-installer build directory with docker_entrypoint script
volume_offline_directory="$(readlink -f $(dirname ${0}))"

# Destination path for created repository
volume_repo_directory="$(pwd)"

# Path inside container with cloned offline-installer build directory
container_offline_volume="/mnt/offline/"

# Target repository path inside container
container_repo_volume="/mnt/repo/"

# Additional packages lists files path within container
container_list_volume="/mnt/additional-lists/"

# Show script usage
help () {
cat <<EOF
Wrapper script running docker container for creating package repository

Repository type is set with --target-platform option and the default is to use host OS platform type

usage: create_repo.sh [OPTION]...


  -d | --destination-repository    target path to store downloaded packages. Current directory by default
  -c | --cloned-directory          path to directory containing this and docker-entrypoint scripts (offline-installer/build directory)
                                   Set it only when you want to use different script/datalists
  -t | --target-platform           target repository platform type (ubuntu/rhel/centos)
  -a | --additional-list           additional packages list; can be used multiple times for more additional lists
  -h | --help                      show this help

If build folder from offline repository is not specified current one will be used by default.
EOF
}

# Get distribution type
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
            # Directory parameter
            # Set path to offline-installer build directory
            volume_offline_directory="$2"
            ;;
        -d|--destination-repository)
            # Repository directory parameter
            # Set destination path for created repository
            volume_repo_directory="$2"
            ;;
        -t|--target-platform)
            # Repository type (rpm/deb)
            # Set target platform for repository
            target_input="$2"
            ;;
        -a|--additional-list)
            # Array of additional packages lists
            additional_lists+=("$2")
            ;;
        *)
            # unknown option
            help # show help
            exit 1
            ;;
    esac
    shift;shift
done

# Check if user specified repository type
# This setting has higher priority than distribution type
if ! test -z "$target_input"
then
    set_enviroment "$target_input"
else
    set_enviroment "$distro_type"
fi

# Check if path contains expected components:
# "resources/pkg/rpm" for Rhel/CentOS or
# "resources/pkg/deb" for Ubuntu/Debian
if ! [[ "/$volume_repo_directory/" = *"/$expected_dir/"* ]]; then
    # Create repo folder if it doesn't exist
    case "$distro_type" in
        ubuntu)
            volume_repo_directory="$volume_repo_directory"/resources/pkg/deb
        ;;
        rhel)
            volume_repo_directory="$volume_repo_directory"/resources/pkg/rpm
        ;;
    esac
    [ ! -d "$volume_repo_directory" ] && mkdir -p $volume_repo_directory
fi

#Check if container "centos-repo" is running
if [ ! "$(docker ps -q -f name=$container_name)" ]; then
    # run repo container
    # name of container $container_name
    # docker entrypoint script from mounted volume
    # with dynamic parameters
    # mount additional packages lists to container
    param_array=()
    mounted_lists=()
    param_array+=(--directory ${container_repo_volume})
    param_array+=(--list ${container_offline_volume}data_lists/)
    param_array+=(--packages-lists-path ${container_list_volume})
    [[ ! ${#additional_lists[@]} -eq 0 ]] && \
        for array_list in "${additional_lists[@]}";
        do
            param_array+=(--additional-list "${array_list##*/}") && \
            mounted_lists+=(-v ${array_list}:${container_list_volume}${array_list##*/})
        done

    docker run -d \
               --name $container_name \
               -v ${volume_offline_directory}:${container_offline_volume} \
               -v ${volume_repo_directory}:${container_repo_volume} \
               "${mounted_lists[@]}" \
               --rm \
               --entrypoint="${container_offline_volume}docker-entrypoint.sh" \
                    -it ${docker_image} \
                    "${param_array[@]}"
    docker logs $(docker ps --filter "name=${container_name}" --format '{{.ID}}' -a) -f
fi
