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

    # install required pip packages for download scripts
    pip install -r ./build/download/requirements.txt

Part 2. Download artifacts for offline installer
------------------------------------------------

.. note:: Skip this step if you have already all necessary resources and continue with Part 3. Populate local nexus

It's possible to download all artifacts in single ./download.py execution but as download might be potentially unreliable despite
all our improvements let's do all required steps one by one with cross-checking that each step in the procedure passed.

**Step 1 - docker images**

::

        # This step will parse all 3 docker datalists (offline infrastructure images, rke k8s images & onap images)
        # and start building onap offline platform in /tmp/resources folder

        ./build/download/download.py --docker ./build/data_lists/infra_docker_images.list ../resources/offline_data/docker_images_infra --docker ./build/data_lists/rke_docker_images.list ../resources/offline_data/docker_images_for_nexus --docker ./build/data_lists/onap_docker_images.list ../resources/offline_data/docker_images_for_nexus


**Step 2 - building own dns image**

::

        # We are building our own dns image within our offline infrastructure
        ./build/creating_data/create_nginx_image/01create-image.sh /tmp/resources/offline_data/docker_images_infra

**Step 3 - git repos**

::

        # Following step will download all git repos
        ./build/download/download.py --git ./build/data_lists/onap_git_repos.list ../resources/git-repo

**Step 4 - http files**

ToDo: complete and verified list of http files will come just during/after vFWCL testcase

**Step 5 - npm packages**

::

        # Following step will download all npm packages
        ./build/download/download.py --npm ./build/data_lists/onap_npm.list ../resources/offline_data/npm_tar

**Step 6 - binaries**

::

       # Following step will download and prepare rke, kubectl and helm binaries
       ./build/download/download-bin-tools.sh ../resources/downloads

**Step 7 - rpms**

::

      # Following step will download all rpms and create repo
      ./build/download/download.py --rpm ./build/data_lists/onap_rpm_packages.list ../resources/pkg/rhel

      createrepo ../resources/pkg/rhel

**Step 8 - pip packages**

Todo: new python script might be created for that part as well

::

      # Following step will download all pip packages
      ./build/download/download-pip.sh ./build/data_lists/onap_pip_packages.list ../resources/offline_data/pypi


This concludes SW download part required for ONAP offline platform creating.

Part 3. Populate local nexus
----------------------------

Prerequisites:

- All data lists and resources which are pushed to local nexus repository are available
- Following ports are not occupied buy another service: 80, 8081, 8082, 10001
- There's no docker container called "nexus"

.. note:: In case you skipped the Part 2 for the artifacts download, please ensure that the copy of resources data are untarred in *./onap-offline/../resources/*

Whole nexus blob data will be created by running script build\_nexus\_blob.sh.
It will load the listed docker images, run the Nexus, configure it as npm, pypi
and docker repositories. Then it will push all listed npm and pypi packages and
docker images to the repositories. After all is done the repository container
is stopped.

You can run the script as following example:

``$ ./install/onap-offline/build_nexus_blob.sh``

.. note:: in Dublin scope we aim to maintain just single example data lists set, tags used in previous releases are not needed. Datalists are also covering latest versions verified by us despite user is allowed to build data lists on his own.

Once the Nexus data blob is created, the docker images and npm and pypi
packages can be deleted to reduce the package size as they won't be needed in
the installation time:

E.g.

::

    rm -f /tmp/resources/offline_data/docker_images_for_nexus/*
    rm -rf /tmp/resources/offline_data/npm_tar
    rm -rf /tmp/resources/offline_data/pypi

Part 4. Application helm charts preparation and patching
--------------------------------------------------------

This is about to clone oom repository and patch it to be able to use it
offline. Use the following command:

::

  ./build/fetch\_and\_patch\_charts.sh <helm charts repo> <commit/tag/branch> <patchfile> <target\_dir>

For example:

::

  ./build/fetch_and_patch_charts.sh https://gerrit.onap.org/r/oom 0b904977dde761d189874d6dc6c527cd45928 /tmp/onap-offline/patches/onap.patch /tmp/oom-clone

Part 5. Creating offline installation package
---------------------------------------------

For the packagin itself it's necessary to prepare configuration. You can
use ./build/package.conf as template or
directly modify it.

There are some parameters needs to be set in configuration file.
Example values below are setup according to steps done in this guide to package ONAP.

+---------------------------------------+------------------------------------------------------------------------------+
| Parameter                             | Description                                                                  |
+=======================================+==============================================================================+
| HELM\_CHARTS\_DIR                     | directory with Helm charts for the application                               |
|                                       |                                                                              |
|                                       | Example: /tmp/oom-clone/kubernetes                                           |
+---------------------------------------+------------------------------------------------------------------------------+
| APP\_CONFIGURATION                    | application install configuration (application_configuration.yml) for        |
|                                       | ansible installer and custom ansible role code directories if any.           |
|                                       |                                                                              |
|                                       | Example::                                                                    |
|                                       |                                                                              |
|                                       |  APP_CONFIGURATION=(                                                         |
|                                       |     /tmp/onap-offline/config/application_configuration.yml                   |
|                                       |     /tmp/onap-offline/patches/onap-patch-role                                |
|                                       |  )                                                                           |
|                                       |                                                                              |
+---------------------------------------+------------------------------------------------------------------------------+
| APP\_BINARY\_RESOURCES\_DIR           | directory with all (binary) resources for offline infra and application      |
|                                       |                                                                              |
|                                       | Example: /tmp/onap-offline/resources                                         |
+---------------------------------------+------------------------------------------------------------------------------+
| APP\_AUX\_BINARIES                    | additional binaries such as docker images loaded during runtime   [optional] |
+---------------------------------------+------------------------------------------------------------------------------+

Offline installer packages are created with prepopulated data via
following command run from onap-offline directory

::

  ./build/package.sh <project> <version> <packaging target directory>

E.g.

::

  ./build/package.sh onap 3.0.2 /tmp/package


So in the target directory you should find tar files with

::

  offline-<PROJECT\_NAME>-<PROJECT\_VERSION>-sw.tar
  offline-<PROJECT\_NAME>-<PROJECT\_VERSION>-resources.tar
  offline-<PROJECT\_NAME>-<PROJECT\_VERSION>-aux-resources.tar
