.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. Copyright 2021 Samsung Electronics Co., Ltd.

Offline Installer Package Build Guide
=====================================

This document describes how to build offline installer packages. The build process should be triggered on a host with internet connectivity. It will retrieve all artifacts required for ONAP deployment based on both - static data list files and dynamically assembled ones. The host used for the procedure in this guide should be preferably a separate build server.

Procedure was completely tested on RHEL 7.6 as it’s the default target installation platform, however with small adaptations it should be applicable also for other platforms.
Some discrepancies when Centos 7.6 is used are described below as well.


Part 1. Prerequisites
---------------------

We assume that procedure is executed on RHEL 7.6 server with \~300G disc space, 16G+ RAM and internet connectivity.

Some additional software packages are required by ONAP Offline platform building tooling. In order to install them following repos have to be configured for RHEL 7.6 platform.



.. note::
   All commands stated in this guide are meant to be run in root shell.

::

    ############
    # RHEL 7.6 #
    ############

    # Register server
    subscription-manager register --username <rhel licence name> --password <password> --auto-attach

    # required by custom docker version recommended by ONAP
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # required by docker dependencies i.e. docker-selinux
    subscription-manager repos --enable=rhel-7-server-extras-rpms

    # epel is required by npm within blob build
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

Alternatively

::

   ##############
   # Centos 7.6 #
   ##############

   # required by custom docker version recommended by ONAP
   yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

   # enable epel repo for npm and jq
   yum install -y epel-release

Subsequent steps are the same on both platforms:

::

    # install following packages
    yum install -y docker-ce-19.03.15 git createrepo expect nodejs npm jq

    # install Python 3
    yum install -y python36 python36-pip

    # ensure docker daemon is running
    service docker start

Then it is necessary to clone all installer and build related repositories and prepare the directory structure.

::

    # prepare the onap build directory structure
    cd /tmp
    git clone https://gerrit.onap.org/r/oom/offline-installer onap-offline
    cd onap-offline

    # install required pip packages for build and download scripts
    pip3 install -r ./build/requirements.txt
    pip3 install -r ./build/download/requirements.txt

Part 2. Download artifacts for offline installer
------------------------------------------------

Generate the actual list of docker images that are defined within OOM helm charts. Run the docker-images-collector.sh script (check script for runtime dependencies) from cloned OOM repository.

At the beginning of the generated list file there is the OOM repo commit sha from which it was created - the same commit reference
should be used in **Part 4. Packages preparation** as *--application-repository_reference* option value.

Following example will create the list to the default path (*build/data_lists/onap_docker_images.list*):

::

    # clone the OOM repository
    git clone https://gerrit.onap.org/r/oom -b <branch> --recurse-submodules /tmp/oom
    #run the collector providing path the the project
    ./build/creating_data/docker-images-collector.sh /tmp/oom/kubernetes/onap

For the list of all available options check script usage info.

.. note::  replace <branch> with OOM branch you want to build

.. note::  docker-images-collector.sh script uses oom/kubernetes/onap/resources/overrides/onap-all.yaml file to find what subsystems are enabled. By default all subsystems are enabled there. Modify the file to disable some of them if needed.

.. note:: Skip this step if you have already all necessary resources and continue with **Part 3. Populate local nexus**

Create repository containing OS packages to be installed on all nodes:

::

    # run create_repo.sh script to download all required packages with their dependencies
    # set destination directory for packages with '-d' parameter 
    # optionally use '-t' parameter to set target platform (host platform by default)
    ./offline-installer/build/create_repo.sh -d $(pwd) -t centos|rhel|ubuntu

.. note:: If script fails due to permissions issue, it could be a problem with SeLinux. It can be fixed by running:
    ::

      # Change security context of directory
      chcon -Rt svirt_sandbox_file_t $(pwd)

Download all required binaries and docker images. Run download.py twice (as shown below) as it does not support mixing downloading docker images to local directory or just being pulled to local docker engine cache in one run. Docker images from *infra_docker_images.list* need to be saved to resources directory while the rest of the images need to be just pulled locally:

::

        # all data lists are taken from ./build/data_lists/ folder by default
        # all resources will be stored in expected folder structure within "../resources" folder
        ./build/download/download.py --docker ./build/data_lists/infra_docker_images.list ../resources/offline_data/docker_images_infra \
        --http ./build/data_lists/infra_bin_utils.list ../resources/downloads

        # second argument for --docker is not present, images are just pulled and cached
        ./build/download/download.py --docker ./build/data_lists/rke_docker_images.list \
        --docker ./build/data_lists/k8s_docker_images.list \
        --docker ./build/data_lists/onap_docker_images.list



Part 3. Populate local nexus
----------------------------

In order to build nexus blob all docker images required for ONAP offline platform should be available locally (see Part 2).

.. note:: In case you skipped the Part 2 for the artifacts download, please ensure that the onap docker images are cached and copy of resources data are untarred in *./onap-offline/../resources/*

*build_nexus_blob.sh* script will run the Nexus container and configure it a docker repository. Then it will push all docker images from previously generated list to it. After all is done the repository container is stopped and it's filesystem gets saved to resources directory.

::

        ./onap-offline/build/build_nexus_blob.sh

It will load the listed docker images, run the Nexus, configure it as npm, pypi and docker repositories. Then it will push all listed docker images to the repositories. After all is done the repository container is stopped.

.. note:: By default the script uses data lists from ./build/data_lists/ directory and saves the blob to ../resources/nexus_data.

.. note:: By default the script uses "nexus" for the container name and publishes 8081 and 8082 ports. Should those names/ports be already taken please check the script options on how to customize them.


Part 4. Packages preparation
----------------------------

ONAP offline deliverable consist of 3 packages:

+---------------------------------------+------------------------------------------------------------------------------------+
| Package                               | Description                                                                        |
+=======================================+====================================================================================+
| sw_package.tar                        | Contains provisioning software and configuration for infrastructure and ONAP       |
+---------------------------------------+------------------------------------------------------------------------------------+
| resources_package.tar                 | Contains all binary data and config files needed to deploy infrastructure and ONAP |
+---------------------------------------+------------------------------------------------------------------------------------+
| aux_package.tar                       | Contains auxiliary input files that can be added to ONAP                           |
+---------------------------------------+------------------------------------------------------------------------------------+

All packages can be created using build/package.py script. Beside of archiving files gathered in the previous steps, script also builds docker images used on infra server.

From onap-offline directory run:

::

  ./build/package.py <helm charts repo> --build-version <version> --application-repository_reference <commit/tag/branch> --output-dir <target\_dir> --resources-directory <target\_dir>

For example:

::

  ./build/package.py https://gerrit.onap.org/r/oom --application-repository_reference <branch> --output-dir /tmp/packages --resources-directory /tmp/resources

.. note::  replace <branch> by branch you want to build

Above command should produce below tar files in the target directory:

::

  sw_package.tar
  resources_package.tar
  aux_package.tar

