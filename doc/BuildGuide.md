# OOM ONAP offline installer Self-Installer Package Build Guide

This document is describing procedure for building offline installer packages. It’s supposed to be triggered on server with internet connectivity and will download all artifacts required for beijing deployment based on our static lists.

Server used for procedure in this guide is preferred to be separate build server and not any of the servers used to install the produced self-installer package. That is because building need some tools to be installed that are needed only on development servers and should not be installed on target runtime servers

Procedure was completely tested on RHEL 7.4 as it’s tested target platform, however with small adaptations it should be applicable also for other platforms.


# Part 1. Preparations

We assume that procedure is executed on:
- Rhel 7.4 server with ~200G disc space, 16G+ RAM
- Internet connectivity

More-over following sw packages has to be installed:
* for the Preparation (Part 1), the Download artifacts for offline installer (Part 2) and the Building ONAP-ME artifacts (Part 4)
  - git
  - wget

* for the Download artifacts for offline installer (Part 2) only
  - createrepo
  - python2-pip
  - patch

* for the Download artifacts for offline installer (Part 2) and the Populate local nexus (Part 3)
  - nodejs
  - jq

* for the Download artifacts for offline installer (Part 2), the Populate local nexus (Part 3) and the Building ONAP-ME artifacts (Part 4)
  - docker (exact version docker-ce-17.03.2)

* for the Building ONAP-ME artifacts (Part 4) only
  - java SDK (recommended java-1.8.0-openjdk-devel)
  - unzip
  - docker compose
  - maven

This can be achieved by following commands:

```
# Register server
subscription-manager register --username <rhel licence name> --password <password> --auto-attach

# enable epel for npm and jq
rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# enable rhel-7-server-e4s-optional-rpms in /etc/yum.repos.d/redhat.repo

# install following packages
yum install -y expect nodejs git wget createrepo python2-pip java-1.8.0-openjdk-devel jq patch unzip

# install docker
curl https://releases.rancher.com/install-docker/17.03.sh | sh

# install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# install maven and set it up for onap related maven files
wget http://www-eu.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
tar xzf apache-maven-3.5.4-bin.tar.gz
mv apache-maven-3.5.4 maven
rm -f /opt/apache-maven-3.5.4-bin.tar.gz
printf '%s\n' 'export M2_HOME=/opt/maven' 'export PATH=${M2_HOME}/bin:${PATH}' >> /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh
wget https://git.onap.org/oparent/plain/settings.xml
mv settings.xml /opt/maven/conf/settings.xml
```

Then it is necessary to clone all installer and build related repositories and prepare the directory structure.

**Note: If login credentials are required, use gerrit username and generated http password**

```
# prepare the onap build directory structure
cd /tmp
git clone -b casablanca https://gerrit.onap.org/r/oom/offline-installer
cd onap-offline
```

# Part 2. Download artifacts for offline installer

**Note: Skip this step if you have already all necessary resources and continue with Part 3. Populate local nexus**

All artifacts should be downloaded by running the download script as follows:

```
./build/download_offline_data_by_lists.sh
```

Download is as reliable as network connectivity to internet, it’s highly recommended to run it in screen and save log file from this script execution for checking if all artifacts were successfully collected. Each start and end of script call should contain timestamp in console output. Downloading consists of 12 steps, which should be checked at the end one-by-one.


**Verify:** *Please take a look on following comments to respective
parts of download script*

\[Step 1/10 Download collected docker images]

=&gt; image download step is quite reliable and contain retry
logic

E.g
```
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
```

\[Step 2/10 Build own nginx image\]

=&gt; there is no hardening in this step, if it failed needs to be
retriggered. It should end with “Successfully built &lt;id&gt;”

\[Step 3/10 Save docker images from docker cache to tarfiles\]

=&gt; quite reliable, retry logic in place

\[Step 4/10 move infra related images to infra folder\]

=&gt; should be safe, precondition is not failing step(3)

\[Step 5/10 Download git repos\]

=&gt; potentially unsafe, no hardening in place. If it not download all
git repos. It has to be executed again. Easiest way is probably to
comment-out other steps in load script and run it again.

E.g.
```
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
```

\[Step 6/10 Download http files\]

\[Step 7/10 Download npm pkgs\]

\[Step 8/10 Download bin tools\]

=&gt; work quite reliably, If it not download all artifacts. Easiest way
is probably to comment-out other steps in load script and run it again.

\[Step 9/10 Download rhel pkgs\]

=&gt; this is the step which will work on rhel only, for other platform
different packages has to be downloaded. We need just couple of rpms,
but those has a lot of dependencies (mostly because of vnc). Script is
also download all perl packages from all repos, but we need around dozen
of them.

Following is considered as sucessfull run of this part:

```
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
```

\[Step 10/10 Download sdnc-ansible-server packages\]

=&gt; there is again no retry logic in this part, it’s collecting
packages for sdnc-ansible-server in the exactly same way how that
container is doing it, however there is a bug in upstream that image in
place won’t work with those packages as old ones are not available and
newer are not compatible with other stuff inside that image

# Part 3. Populate local nexus

Prerequisites:
- All data lists and resources which are pushed to local nexus repository are available (docker images in tarballs and npm packages).
- Following ports are not occupied buy another service: 80, 8081, 8082, 10001
- There's no docker container called "nexus"

**Note: In case you skipped the Part 2 for the artifacts download, please ensure that the copy of resources data are untarred in ./install/onap-offline/resources/**

Whole nexus blob data tarball will be created by running script build_nexus_blob.sh. It will load the listed docker images, run the Nexus, configure it as npm and docker repository. Then it will push all listed npm packages and docker images to the repositories. After all is done the repository container is stopped and from the nexus-data directory is created tarball.

There are mandatory parameters need to be set in configuration file:

| Parameter | Description |
| --- | --- |
| NXS_SRC_DOCKER_IMG_DIR | resource directory of docker images |
| NXS_SRC_NPM_DIR | resource directory of npm packages |
| NXS_DOCKER_IMG_LIST | list of docker images to be pushed to Nexus repository |
| NXS_DOCKER_WO_LIST | list of docker images which uses default repository |
| NXS_NPM_LIST | list of npm packages to be published to Nexus repository |
| NEXUS_DATA_TAR | target tarball of Nexus data path/name |
| NEXUS_DATA_DIR | directory used for the Nexus blob build |
| NEXUS_IMAGE | Sonatype/Nexus3 docker image which will be used for data blob creation for this script |

Some of the docker images using default registry requires special treatment (e.g. they use different ports or SSL connection), therefore there is the list NXS_DOCKER_WO_LIST by which are the images retagged to be able to push them to our nexus repository.

**Note: It's recomended to use abolute paths in the configuration file for the current script**

Example of the configuration file:
```
NXS_SRC_DOCKER_IMG_DIR="/tmp/onap/install/onap-offline/resources/offline_data/docker_images_for_nexus"
NXS_SRC_NPM_DIR="/tmp/onap/install/onap-offline/resources/offline_data/npm_tar"
NXS_DOCKER_IMG_LIST="/tmp/onap/install/onap-me-data_lists/docker_img.list"
NXS_DOCKER_WO_LIST="/tmp/onap/install/onap-me-data_lists/docker_no_registry.list"
NXS_NPM_LIST="/tmp/onap/install/onap-offline/bash/tools/data_list/npm_list.txt"
NEXUS_DATA_TAR="/root/nexus_data.tar"
NEXUS_DATA_DIR="/tmp/onap/install/onap-offline/resources/nexus_data"
NEXUS_IMAGE="/tmp/onap/install/onap-offline/resources/offline_data/docker_images_infra/sonatype_nexus3_latest.tar"
```

Once everything is ready you can run the script as following example:

```$ ./install/onap-offline/build_nexus_blob.sh /root/nexus_build.conf```

Where the nexus_build.conf is the configuration file and the /root/nexus_data.tar is the destination tarball

**Note: Move, link or mount the NEXUS_DATA_DIR to the resources directory if there was different directory specified in configuration or use the resulting nexus_data.tar for movement between machines.**

Once the Nexus data blob is created, the docker images and npm packages can be deleted to reduce the package size as they won't be needed in the installation time:

E.g.
```
rm -f /tmp/onap/install/onap-offline/resources/offline_data/docker_images_for_nexus/*
rm -rf /tmp/onap/install/onap-offline/resources/offline_data/npm_tar
```

# Part 4. Application helm charts preparation and patching

This is about to clone oom repository and patch it to be able to use it offline. Use the following command:

./build/fetch_and_patch_charts.sh &lt;helm charts repo&gt; &lt;commit/tag/branch&gt; &lt;patchfile&gt; &lt;target_dir&gt;

For example:

```$./build/fetch_and_patch_charts.sh https://gerrit.onap.org/r/oom 3.0.0-ONAP /root/offline-installer/patches/casablanca_3.0.0.patch /tmp/offline-installer/ansible/application/helm_charts```


# Part 5. Creating offline installation package:

For the packagin itself it's necessary to prepare configuration. You can use ./onap/install/onap-offline/build/package.conf as template or directly modify it.

There are some parameters needs to be set in configuration file and some are optional:

| Parameter | Description |
| --- | --- |
| SOFTWARE_PACKAGE_BASENAME | defines package name prefix (e.g. onap-offline) |
| HELM_CHARTS_DIR | oom directory from oom git repostitory |
| SW_PACKAGE_ADDONS | specific entries which are inserted into ./ansible/application |
| EXTERNAL_BINARIES_PACKAGE_ADDONS | other addons used as resources |
| PREPARE_AUX_PACKAGE | boolean condition if prepare AUX package [optional] |
| AUX_BINARIES_PACKAGE_ADDONS | additional binaries such as docker images loaded during runtime [optional] |

Offline installer packages are created with prepopulated data via following command run from offline-installer directory

./build/package.sh &lt;project&gt; &lt;version&gt; &lt;packaging target directory&gt;

E.g.

```$./build/package.sh onap-me 1.0.1  /tmp/package_onap-me_1.0.0"```

So in the target directory you should find tar files with 

&lt;PACKAGE_BASE_NAME&gt;-&lt;PROJECT_NAME&gt;-&lt;PROJECT_VERSION&gt;-sw.tar

&lt;PACKAGE_BASE_NAME&gt;-&lt;PROJECT_NAME&gt;-&lt;PROJECT_VERSION&gt;-resources.tar

Optionally: &lt;PACKAGE_BASE_NAME&gt;-&lt;PROJECT_NAME&gt;-&lt;PROJECT_VERSION&gt;-aux-resources.tar