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

More-over following sw packages has to be installed:

* for the Preparation (Part 1), the Download artifacts for offline installer (Part 2) and the application helm charts preparation and patching (Part 4)
    -  git
    -  wget

* for the Download artifacts for offline installer (Part 2) only
    -  createrepo
    -  dpkg-dev
    -  python2-pip

* for the Download artifacts for offline installer (Part 2) and the Populate local nexus (Part 3)
    -  nodejs
    -  jq
    -  docker (exact version docker-ce-18.09.5)

* for the Download artifacts for offline installer (Part 2) and for the Application helm charts preparation and patching (Part 4)
    -  patch

* for the Populate local nexus (Part 3)
    -  twine

Configure repos for downloading all needed rpms for download/packaging tooling:


::

    ############
    # RHEL 7.6 #
    ############

    # Register server
    subscription-manager register --username <rhel licence name> --password <password> --auto-attach

    # enable epel for npm and jq
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

    # enable rhel-7-server-e4s-optional-rpms in /etc/yum.repos.d/redhat.repo

Alternatively

::

   ##############
   # Centos 7.6 #
   ##############

   # enable epel repo for npm and jq
   yum install -y epel-release

Subsequent steps are the same on both platforms:

::

    # install following packages
    yum install -y expect nodejs git wget createrepo python2-pip jq patch dpkg-dev

    pip install twine

    # install docker
    curl https://releases.rancher.com/install-docker/18.09.sh | sh

Then it is necessary to clone all installer and build related repositories and prepare the directory structure.

::

    # prepare the onap build directory structure
    cd /tmp
    git clone https://gerrit.onap.org/r/oom/offline-installer onap-offline
    cd onap-offline

Part 2. Download artifacts for offline installer
------------------------------------------------

.. note:: Skip this step if you have already all necessary resources and continue with Part 3. Populate local nexus

All artifacts should be downloaded by running the download script as follows:

./build/download_offline_data_by_lists.sh <project>

For example:

::

  # onap_3.0.0 for casablanca                                (sign-off 30/11/2018)
  # onap_3.0.1 for casablanca maintenance release            (sign-off 10/12/2018)
  # onap_3.0.2 for latest casablanca with fixed certificates (sign-off 25/04/2019)

  $ ./build/download_offline_data_by_lists.sh onap_3.0.2

Download is as reliable as network connectivity to internet, it is highly recommended to run it in screen and save log file from this script execution for checking if all artifacts were successfully collected. Each start and end of script call should contain timestamp in console output. Downloading consists of 10 steps, which should be checked at the end one-by-one.

**Verify:** *Please take a look on following comments to respective
parts of download script*

[Step 1/10 Download collected docker images]

=> image download step is quite reliable and contain retry logic

E.g

::

    == pkg #143 of 163 ==
    rancher/etc-host-updater:v0.0.3
    digest:sha256:bc156a5ae480d6d6d536aa454a9cc2a88385988617a388808b271e06dc309ce8
    Error response from daemon: Get https://registry-1.docker.io/v2/rancher/etc-host-updater/manifests/v0.0.3: Get
    https://auth.docker.io/token?scope=repository%3Arancher%2Fetc-host-updater%3Apull&service=registry.docker.io: net/http: TLS handshake timeout
    WARNING [!]: warning Command docker -l error pull rancher/etc-host-updater:v0.0.3 failed.
    Attempt: 2/5
    INFO: info waiting 10s for another try...
    v0.0.3: Pulling from rancher/etc-host-updater
    b3e1c725a85f: Already exists
    6a710864a9fc: Already exists
    d0ac3b234321: Already exists
    87f567b5cf58: Already exists
    16914729cfd3: Already exists
    83c2da5790af: Pulling fs layer
    83c2da5790af: Verifying Checksum
    83c2da5790af: Download complete
    83c2da5790af: Pull complete

[Step 2/10 Build own nginx image]

=> there is no hardening in this step, if it fails it needs to be
retriggered. It should end with

::

  Successfully built <id>

[Step 3/10 Save docker images from docker cache to tarfiles]

=> quite reliable, retry logic in place

[Step 4/10 move infra related images to infra folder]

=> should be safe, precondition is not failing step(3)

[Step 5/10 Download git repos]

=> potentially unsafe, no hardening in place. If it not download all git repos. It has to be executed again. Easiest way is probably to comment-out other steps in load script and run it again.

E.g.

::

    Cloning into bare repository
    'github.com/rancher/community-catalog.git'...
    error: RPC failed; result=28, HTTP code = 0
    fatal: The remote end hung up unexpectedly
    Cloning into bare repository 'git.rancher.io/rancher-catalog.git'...
    Cloning into bare repository
    'gerrit.onap.org/r/testsuite/properties.git'...
    Cloning into bare repository 'gerrit.onap.org/r/portal.git'...
    Cloning into bare repository 'gerrit.onap.org/r/aaf/authz.git'...
    Cloning into bare repository 'gerrit.onap.org/r/demo.git'...
    Cloning into bare repository
    'gerrit.onap.org/r/dmaap/messagerouter/messageservice.git'...
    Cloning into bare repository 'gerrit.onap.org/r/so/docker-config.git'...

[Step 6/10 Download http files]

[Step 7/10 Download npm pkgs]

[Step 8/10 Download bin tools]

=> work quite reliably, If it not download all artifacts. Easiest way is probably to comment-out other steps in load script and run it again.

[Step 9/10 Download rhel pkgs]

=> this is the step which will work on rhel only, for other platform different packages has to be downloaded.

Following is considered as sucessfull run of this part:

::

      Available: 1:net-snmp-devel-5.7.2-32.el7.i686 (rhel-7-server-rpms)
        net-snmp-devel = 1:5.7.2-32.el7
      Available: 1:net-snmp-devel-5.7.2-33.el7_5.2.i686 (rhel-7-server-rpms)
        net-snmp-devel = 1:5.7.2-33.el7_5.2
    Dependency resolution failed, some packages will not be downloaded.
    No Presto metadata available for rhel-7-server-rpms
    https://ftp.icm.edu.pl/pub/Linux/fedora/linux/epel/7/x86_64/Packages/p/perl-CDB_File-0.98-9.el7.x86_64.rpm:
    [Errno 12\] Timeout on
    https://ftp.icm.edu.pl/pub/Linux/fedora/linux/epel/7/x86_64/Packages/p/perl-CDB_File-0.98-9.el7.x86_64.rpm:
    (28, 'Operation timed out after 30001 milliseconds with 0 out of 0 bytes
    received')
    Trying other mirror.
    Spawning worker 0 with 230 pkgs
    Spawning worker 1 with 230 pkgs
    Spawning worker 2 with 230 pkgs
    Spawning worker 3 with 230 pkgs
    Spawning worker 4 with 229 pkgs
    Spawning worker 5 with 229 pkgs
    Spawning worker 6 with 229 pkgs
    Spawning worker 7 with 229 pkgs
    Workers Finished
    Saving Primary metadata
    Saving file lists metadata
    Saving other metadata
    Generating sqlite DBs
    Sqlite DBs complete

[Step 10/10 Download sdnc-ansible-server packages]

=> there is again no retry logic in this part, it is collecting packages for sdnc-ansible-server in the exactly same way how that container is doing it, however there is a bug in upstream that image in place will not work with those packages as old ones are not available and newer are not compatible with other stuff inside that image

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

``$ ./install/onap-offline/build_nexus_blob.sh onap_3.0.2``

Where the onap_3.0.2 is the tag to specify which lists will be used for the
resources

Once the Nexus data blob is created, the docker images and npm and pypi
packages can be deleted to reduce the package size as they won't be needed in
the installation time:

E.g.

::

    rm -f /tmp/onap-offline/resources/offline_data/docker_images_for_nexus/*
    rm -rf /tmp/onap-offline/resources/offline_data/npm_tar
    rm -rf /tmp/onap-offline/resources/offline_data/pypi

Part 4. Application helm charts preparation and patching
--------------------------------------------------------

This is about to clone oom repository and patch it to be able to use it
offline. Use the following command:

::

  ./build/fetch\_and\_patch\_charts.sh <helm charts repo> <commit/tag/branch> <patchfile> <target\_dir>

For example:

::

  ./build/fetch_and_patch_charts.sh https://gerrit.onap.org/r/oom 3.0.2-ONAP /tmp/onap-offline/patches/casablanca.patch /tmp/oom-clone

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
|                                       |     /tmp/onap-offline/config/application_configuration.yml              |
|                                       |     /tmp/onap-offline/patches/onap-casablanca-patch-role                |
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
