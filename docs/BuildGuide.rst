.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. Copyright 2019 Samsung Electronics Co., Ltd.

OOM ONAP Offline Installer Package Build Guide
=============================================================

This document is describing procedure for building offline installer packages. It is supposed to be triggered on server with internet connectivity and will download all artifacts required for ONAP deployment based on our static lists. The server used for the procedure in this guide is preferred to be separate build server.

Procedure was completely tested on RHEL 7.6 as it’s tested target platform, however with small adaptations it should be applicable also for other platforms.
Some discrepancies when Centos 7.6 is used are described below as well.

Part 1. Preparations
--------------------

We assume that procedure is executed on RHEL 7.6 server with \~300G disc space, 16G+ RAM and internet connectivity

Some additional sw packages are required by ONAP Offline platform building tooling. in order to install them
following repos has to be configured for RHEL 7.6 platform.



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

   ToDo: newer download scripts needs to be verified on Centos with ONAP Dublin

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
    yum install -y docker-ce-18.09.5 python-pip git createrepo expect nodejs npm jq

    # install Python 3 (download scripts don't support Python 2 anymore)
    yum install -y python36 python36-pip

    # twine package is needed by nexus blob build script
    pip install twine

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

.. note::
   It is possible to generate actual list of docker images using docker-images-collector.sh (helm is required) from cloned OOM directory
   based on enabled subsystems.

   In the beginning of the generated list is written commit number from which it was created - the same commit number should be used
   in Part 4. Packages preparation.

   Following example will create the list to the default path:
   ::

    # clone the OOM repository
    git clone https://gerrit.onap.org/r/oom -b master /tmp/oom

    # enable subsystems in oom/kubernetes/onap/values.yaml as required

    #run the collector providing path the the project
    ./build/creating_data/docker-images-collector.sh /tmp/oom/kubernetes/onap

   If the list does not contain any image, no subsystem is enabled in the oom/kubernetes/onap/values.yaml

   For the other options check the usage of the script.

.. note:: Skip this step if you have already all necessary resources and continue with Part 3. Populate local nexus

Before downloading artifacts with ./download.py script is necessary to create local repository with RPM packages.
This repository is created with docker container where is downloaded and stored in ../resources/pkg/rhel directory.

::
    # run the docker container with actual directory of offline-installer and resources
    ./offline-installer/build/create_repo.sh -d $(pwd)

.. note::
    If script fails with permissions, problem could be with SeLinux. Issue is possible to solve by:
    ::
      # Change security context of directory
      chcon -Rt svirt_sandbox_file_t $(pwd)

It's possible to download rest artifacts in single ./download.py execution. Recently we improved reliability of download scripts
so one might try following command to download most of the required artifacts in single shot.

::

        # following arguments are provided
        # all data lists are taken in ./build/data_lists/ folder
        # all resources will be stored in expected folder structure within ../resources folder
        # for more details refer to Appendix 1.

        ./build/download/download.py --docker ./build/data_lists/infra_docker_images.list ../resources/offline_data/docker_images_infra \
        --docker ./build/data_lists/rke_docker_images.list ../resources/offline_data/docker_images_for_nexus \
        --docker ./build/data_lists/onap_docker_images.list ../resources/offline_data/docker_images_for_nexus \
        --git ./build/data_lists/onap_git_repos.list ../resources/git-repo \
        --npm ./build/data_lists/onap_npm.list ../resources/offline_data/npm_tar \
        --pypi ./build/data_lists/onap_pip_packages.list ../resources/offline_data/pypi \
        --http ./build/data_lists/infra_bin_utils.list ../resources/downloads


Alternatively, step-by-step procedure is described in Appendix 1.

This concludes SW download part required for ONAP offline platform creating.

Part 3. Populate local nexus
----------------------------

Prerequisites:

- All data lists and resources which are pushed to local nexus repository are available
- Following ports are not occupied buy another service: 80, 8081, 8082, 10001
- There's no docker container called "nexus"

.. note:: In case you skipped the Part 2 for the artifacts download, please ensure that the copy of resources data are untarred in *./onap-offline/../resources/*

Whole nexus blob data will be created by running script build_nexus_blob.sh.
It will load the listed docker images, run the Nexus, configure it as npm, pypi
and docker repositories. Then it will push all listed npm and pypi packages and
docker images to the repositories. After all is done the repository container
is stopped.

.. note:: build_nexus_blob.sh script is using docker, npm and pip data lists for building nexus blob. Unfortunatelly we now have 2 different docker data lists (RKE & ONAP). So we need to merge them as visible from following snippet. This problem will be fixed in OOM-1890

You can run the script as following example:

::

        # merge RKE and ONAP app data lists
        cat ./build/data_lists/rke_docker_images.list >> ./build/data_lists/onap_docker_images.list

        ./build/build_nexus_blob.sh

.. note:: in current release scope we aim to maintain just single example data lists set, tags used in previous releases are not needed. Datalists are also covering latest versions verified by us despite user is allowed to build data lists on his own.

Once the Nexus data blob is created, the docker images and npm and pypi
packages can be deleted to reduce the package size as they won't be needed in
the installation time:

E.g.

::

    rm -f /tmp/resources/offline_data/docker_images_for_nexus/*
    rm -rf /tmp/resources/offline_data/npm_tar
    rm -rf /tmp/resources/offline_data/pypi

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

All packages can be created using script build/package.py. Beside of archiving files gathered in the previous steps, script also builds installer software and apply patch over application repository to make it usable without internet access.

From onap-offline directory run:

::

  ./build/package.py <helm charts repo> --application-repository_reference <commit/tag/branch> --application-patch_file <patchfile> --output-dir <target\_dir> --resources-directory <target\_dir>

For example:

::

  ./build/package.py https://gerrit.onap.org/r/oom --application-repository_reference master --application-patch_file ./patches/onap.patch --output-dir ../packages --resources-directory ../resources


In the target directory you should find tar files:

::

  sw_package.tar
  resources_package.tar
  aux_package.tar


Appendix 1. Step-by-step download procedure
-------------------------------------------

**Step 1 - docker images**

::

        # This step will parse all 3 docker datalists (offline infrastructure images, rke k8s images & onap images)
        # and start building onap offline platform in /tmp/resources folder

        ./build/download/download.py --docker ./build/data_lists/infra_docker_images.list ../resources/offline_data/docker_images_infra \
        --docker ./build/data_lists/rke_docker_images.list ../resources/offline_data/docker_images_for_nexus \
        --docker ./build/data_lists/onap_docker_images.list ../resources/offline_data/docker_images_for_nexus


**Step 2 - git repos**

::

        # Following step will download all git repos
        ./build/download/download.py --git ./build/data_lists/onap_git_repos.list ../resources/git-repo


**Step 3 - npm packages**

::

        # Following step will download all npm packages
        ./build/download/download.py --npm ./build/data_lists/onap_npm.list ../resources/offline_data/npm_tar

**Step 4 - binaries**

::

       # Following step will download rke, kubectl and helm binaries
       ./build/download/download.py --http ./build/data_lists/infra_bin_utils.sh ../resources/downloads

**Step 5 - rpms**

::

      # Following step will download all rpms and create repo
      ./build/download/download.py --rpm ./build/data_lists/onap_rpm.list ../resources/pkg/rhel

      createrepo ../resources/pkg/rhel

**Step 6 - pip packages**

::

      # Following step will download all pip packages
      ./build/download/download.py --pypi ./build/data_lists/onap_pip_packages.list ../resources/offline_data/pypi

