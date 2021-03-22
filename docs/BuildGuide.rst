.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. Copyright 2021 Samsung Electronics Co., Ltd.

Offline Installer Package Build Guide
=====================================

This document is describing procedure for building offline installer packages. It is supposed to be triggered on server with internet connectivity and will download all artifacts required for ONAP deployment based on our static lists. The server used for the procedure in this guide is preferred to be separate build server.

Procedure was completely tested on RHEL 7.6 as it’s tested target platform, however with small adaptations it should be applicable also for other platforms.
Some discrepancies when Centos 7.6 is used are described below as well.


Part 1. Prerequisites
---------------------

We assume that procedure is executed on RHEL 7.6 server with \~300G disc space, 16G+ RAM and internet connectivity

Some additional sw packages are required by ONAP Offline platform building tooling. in order to install them
following repos has to be configured for RHEL 7.6 platform.



.. note::
   All commands stated in this guide are meant to be run in root shell.

::

    ############
    # RHEL 7.6 #
    ############

    # Register server
    subscription-manager register --username <rhel licence name> --password <password> --auto-attach

    # required by special centos docker recommended by ONAP
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

   # required by special centos docker recommended by ONAP
   yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

   # enable epel repo for npm and jq
   yum install -y epel-release

Subsequent steps are the same on both platforms:

::

    # install following packages
    yum install -y docker-ce-19.03.15 git createrepo expect nodejs npm jq

    # install Python 3
    yum install -y python36 python36-pip

    # docker daemon must be running on host
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

Generate actual list of docker images using docker-images-collector.sh (helm binary is required) from cloned OOM repository
based on enabled subsystems.

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

Repository containing packages to be installed on all nodes needs to be created:

::

    # run the docker container with -d parameter for destination directory with RPM packages and optionally use -t parameter for target platform. Supported target platforms are centos|rhel|ubuntu. If -t parameter is not given, default platform is based on host platform where script is running.
    ./offline-installer/build/create_repo.sh -d $(pwd) -t centos|rhel|ubuntu

.. note:: If script fails due to permissions issue, it could be a problem with SeLinux. It can be fixed by running:
    ::

      # Change security context of directory
      chcon -Rt svirt_sandbox_file_t $(pwd)

It's possible to download rest artifacts in single ./download.py execution. Recently we improved reliability of download scripts
so one might try following command to download most of the required artifacts in single shot.

::

        # following arguments are provided
        # all data lists are taken from ./build/data_lists/ folder
        # all resources will be stored in expected folder structure within ../resources folder

        ./build/download/download.py --docker ./build/data_lists/infra_docker_images.list ../resources/offline_data/docker_images_infra \
        --http ./build/data_lists/infra_bin_utils.list ../resources/downloads

        # following docker images do not necessarily need to be stored under resources as they load into repository in next part
        # if second argument for --docker is not present, images are just pulled and cached.
        # Warning: script must be run twice separately, for more details run download.py --help
        ./build/download/download.py --docker ./build/data_lists/rke_docker_images.list \
        --docker ./build/data_lists/k8s_docker_images.list \
        --docker ./build/data_lists/onap_docker_images.list \


This concludes SW download part required for ONAP offline platform creating.

Part 3. Populate local nexus
----------------------------

Prerequisites:

- All data lists and resources which are pushed to local nexus repository are available
- Following ports are not occupied by another service: 80, 8081, 8082, 10001
- There's no docker container called "nexus"

.. note:: In case you skipped the Part 2 for the artifacts download, please ensure that the onap docker images are cached and copy of resources data are untarred in *./onap-offline/../resources/*

::

        #Whole nexus blob data will be created by running script build_nexus_blob.sh.
        ./onap-offline/build/build_nexus_blob.sh

It will load the listed docker images, run the Nexus, configure it as npm, pypi
and docker repositories. Then it will push all listed docker images to the repositories. After all is done the repository container is stopped.

.. note:: In the current release scope we aim to maintain just single example data lists set, tags used in previous releases are not needed. Datalists are also covering latest versions verified by us despite user is allowed to build data lists on his own.


Part 4. Packages preparation
--------------------------------------------------------

ONAP offline deliverable consist of 3 packages:

+---------------------------------------+------------------------------------------------------------------------------+
| Package                               | Description                                                                  |
+=======================================+==============================================================================+
| sw_package.tar                        | Contains installation software and configuration for infrastructure and ONAP |
+---------------------------------------+------------------------------------------------------------------------------+
| resources_package.tar                 | Contains all input files  needed to deploy infrastructure and ONAP           |
+---------------------------------------+------------------------------------------------------------------------------+
| aux_package.tar                       | Contains auxiliary input files that can be added to ONAP                     |
+---------------------------------------+------------------------------------------------------------------------------+

All packages can be created using script build/package.py. Beside of archiving files gathered in the previous steps, script also builds docker images used in on infra server.

From onap-offline directory run:

::

  ./build/package.py <helm charts repo> --build-version <version> --application-repository_reference <commit/tag/branch> --output-dir <target\_dir> --resources-directory <target\_dir>

For example:

::

  ./build/package.py https://gerrit.onap.org/r/oom --application-repository_reference <branch> --output-dir /tmp/packages --resources-directory /tmp/resources

.. note::  replace <branch> by branch you want to build

In the target directory you should find tar files:

::

  sw_package.tar
  resources_package.tar
  aux_package.tar

