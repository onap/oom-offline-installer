.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. Copyright 2019 Samsung Electronics Co., Ltd.

.. _oooi_installguide:

OOM ONAP Offline Installer - Installation Guide
===============================================

This document describes the correct offline installation procedure for `OOM ONAP`_, which is done by the ansible based `offline-installer <https://gerrit.onap.org/r/#/admin/projects/oom/offline-installer>`_.

Before you dive into the installation you should prepare the offline installer itself - the installer consists of at least two packages/resources. You can read about it in the `Build Guide`_, which provides the instructions for creating them.

This current version of the *Installation Guide* supports `El Alto release`_.

-----

.. _oooi_installguide_preparations:

Part 1. Prerequisites
---------------------

OOM ONAP deployment has certain hardware resource requirements - `El Alto requirements`_:

Community recommended footprint from `El Alto requirements`_ page is 16 VMs ``224 GB RAM`` and ``112 vCPUs``. We will not follow strictly this setup due to such demanding resource consumption and so we will deploy our installation across four nodes (VMs) instead of sixteen. Our simplified setup is definitively not supported or recommended - you are free to diverge - you can follow the official guidelines or make completely different layout, but the minimal count of nodes should not drop below three - otherwise you may have to do some tweaking to make it work, which is not covered here (there is a pod count limit for a single kubernetes node - you can read more about it in this `discussion <https://lists.onap.org/g/onap-discuss/topic/oom_110_kubernetes_pod/25213556>`_).

.. _oooi_installguide_preparations_k8s_cluster:

Kubernetes cluster
~~~~~~~~~~~~~~~~~~

The four nodes/VMs will be running these services:

- **infra-node**::

    - nexus
    - nginx proxy
    - dns
    - kubernetes-etcd
    - kubernetes-control-plane

**NOTE:** kubernetes-* roles can be collocated directly with kubernetes nodes and not necessarily on infra node. 

- **kubernetes node 1-3**::

    - kubernetes worker

You don't need to care about these services now - that is the responsibility of the installer (described below). Just start four VMs as seen in this table (or according to your needs as we hinted above):

.. _Overview table of the kubernetes cluster:

Kubernetes cluster overview
^^^^^^^^^^^^^^^^^^^^^^^^^^^

In El Alto we are using RKE as k8s orchestrator method, however everyone is free to diverge from this example and can set it up in own way omitting our rke playbook execution. 

=================== ================== ==================== ============== ============ ===============
KUBERNETES NODE     OS                 NETWORK              CPU            RAM          STORAGE
=================== ================== ==================== ============== ============ ===============
**infra-node**      RHEL/CentOS 7.6    ``10.8.8.100/24``    ``8 vCPUs``    ``8 GB``     ``100 GB``
**kube-node1**      RHEL/CentOS 7.6    ``10.8.8.101/24``    ``16 vCPUs``   ``56+ GB``   ``100 GB``
**kube-node2**      RHEL/CentOS 7.6    ``10.8.8.102/24``    ``16 vCPUs``   ``56+ GB``   ``100 GB``
**kube-node3**      RHEL/CentOS 7.6    ``10.8.8.103/24``    ``16 vCPUs``   ``56+ GB``   ``100 GB``
SUM                                                         ``56 vCPUs``   ``176+ GB``  ``400 GB``
=========================================================== ============== ============ ===============

Unfortunately, the offline installer supports only **RHEL 7.x** or **CentOS 7.6** distribution as of now. So, your VMs should be preinstalled with this operating system - the hypervisor and platform can be of your choosing.

We will expect from now on that you installed four VMs and they are connected to the shared network. All VMs must be reachable from our *install-server* (below), which can be the hypervisor, *infra-node* or completely different machine. But in either of these cases the *install-server* must be able to connect over ssh to all of these nodes.

.. _oooi_installguide_preparations_installserver:

Install-server
~~~~~~~~~~~~~~

We will use distinct *install-server* and keep it separate from the four-node cluster. But if you wish so, you can use *infra-node* for this goal (if you use the default ``'chroot'`` option of the installer), but in that case double the size of the storage requirement!

Prerequisites for the *install-server*:

- packages described in `Build Guide`_
- extra ``100 GB`` storage (to have space where to store these packages)
- installed ``'chroot'`` and/or ``'docker'`` system commands
- network connection to the nodes - especially functioning ssh client

Our *install-server* will have ip: ``10.8.8.4``.

**NOTE:** All the subsequent commands below, are executed from within this *install-server*.

-----

.. _oooi_installguide_config:

Part 2. Preparation and configuration
-------------------------------------

We *MUST* do all the following instructions from the *install-server* and also we will be running them as a user ``root``. But that is not necessary - you can without any problem pick and use a regular user. The ssh/ansible connection to the nodes will also expect that we are connecting as a ``root`` - you need to elevate privileges to be able to install on them. Although it can be achieved by other means (sudo), we decided here to keep instructions simple.

.. _oooi_installguide_config_packages:

Installer packages
~~~~~~~~~~~~~~~~~~

As was stated above you must have prepared the installer packages (names will differ - check out the `Build Guide`_):

- sw_package.tar
- resources_package.tar
- aux_package.tar

**NOTE:** ``'aux_package.tar'`` is optional and if you don't have use for it, you can ignore it.

We will store them in the ``/data`` directory on the *install-server* and then we will unpack the ``'sw'`` package to your home directory for example::

    $ mkdir ~/onap-offline-installer
    $ tar -C ~/onap-offline-installer -xf /data/sw_package.tar

.. _oooi_installguide_config_app:

Application directory
~~~~~~~~~~~~~~~~~~~~~

Change the current directory to the ``'ansible'``::

    $ cd ~/onap-offline-installer/ansible

You can see multiple files and directories inside - this is the *offline-installer*. It is implemented as a set of ansible playbooks.

If you created the ``'sw'`` package according to the *Build Guide* then you should have had the *offline-installer* populated with at least the following files:

- ``application/application_configuration.yml``
- ``inventory/hosts.yml``

Following paragraphs describe fine-tuning of ``'inventory.yml'`` and ``'application_configuration.yml'`` to reflect your VMs setup.

.. _oooi_installguide_config_hosts:

hosts.yml
~~~~~~~~~

We need to setup the ``'hosts.yml'`` first, the template looks like this::

    ---
    # This group contains hosts with all resources (binaries, packages, etc.)
    # in tarball.
    all:
      vars:
        # this key is supposed to be generated during setup.yml playbook execution
        # change it just when you have better one working for all nodes
        ansible_ssh_private_key_file: /root/.ssh/offline_ssh_key
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

      children:
        resources:
          hosts:
            resource-host:
              ansible_host: 10.8.8.5

        # This is group of hosts where nexus, nginx, dns and all other required
        # services are running.
        infrastructure:
          hosts:
            infrastructure-server:
              ansible_host: 10.8.8.13
              #IP used for communication between infra and kubernetes nodes, must be specified.
              cluster_ip: 10.8.8.13

        # This is group of hosts which are/will be part of Kubernetes cluster.
        kubernetes:
          children:
            # This is a group of hosts containing kubernetes worker nodes.
            kubernetes-node:
              hosts:
                kubernetes-node-1:
                  ansible_host: 10.8.8.19
                  #ip of the node that it uses for communication with k8s cluster.
                  cluster_ip: 10.8.8.19

            # Group of hosts containing etcd cluster nodes.
            # Defaults to infra.
            kubernetes-etcd:
              hosts:
                infrastructure-server

            # This is a group of hosts that are to be used as kubernetes control plane nodes.
            # This means they host kubernetes api server, controller manager and scheduler.
            # This example uses infra for this purpose, however note that any
            # other host could be used including kubernetes nodes.
            # cluster_ip needs to be set for hosts used as control planes.
            kubernetes-control-plane:
              hosts:
                infrastructure-server

        nfs-server:
          hosts:
            kubernetes-node-1

There is some ssh configuration under the ``'vars'`` section - we will deal with ssh setup a little bit later in the `SSH authentication`_.

We need to first correct the ip addresses and add a couple of kubernetes nodes to match our four-node cluster:

- Under the ``'resource-host'`` set the ``'ansible_host'`` address to the ip of your server, where the packages are stored - it must be reachable by ssh from the *install-server* (for ansible to run playbooks on it)  **AND** *infra-node* (to extract resource data from *resource-host* to *infra-node* over ssh). In our scenario the *resource-host* is the same as the *install-server*: ``'10.8.8.4'``
- Similarly, set the ``'ansible_host'`` to the address of the *infra-node* under the ``'infrastructure-server'``.
- Copy the whole ``'kubernetes-node-1'`` subsection and paste it twice directly after.  Change the numbers to ``'kubernetes-node-2'`` and ``'kubernetes-node-3'`` respectively and fix the addresses in the ``'ansible_host'`` variables again to match *kube-node1*, *kube-node2* and *kube-node3*.

As you can see, there is another ``'cluster_ip'`` variable for each node - this serve as a designated node address in the kubernetes cluster. Make it the same as the respective ``'ansible_host'``.

**NOTE:** In our simple setup we have only one interface per node, but that does not need to be a case for some other deployment - especially if we start to deal with a production usage. Basically, an ``'ansible_host'`` is an entry point for the *install-server's* ansible (*offline-installer*), but the kubernetes cluster can be communicating on a separate network to which *install-server* has no access. That is why we have this distinctive variable, so we can tell the installer that there is a different network, where we want to run the kubernetes traffic and what address each node has on such a network.

After all the changes, the ``'hosts.yml'`` should look similar to this::

    ---
    # This group contains hosts with all resources (binaries, packages, etc.)
    # in tarball.
    all:
      vars:
        # this key is supposed to be generated during setup.yml playbook execution
        # change it just when you have better one working for all nodes
        ansible_ssh_private_key_file: /root/.ssh/offline_ssh_key
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

      children:
        resources:
          hosts:
            resource-host:
              ansible_host: 10.8.8.4

        # This is group of hosts where nexus, nginx, dns and all other required
        # services are running.
        infrastructure:
          hosts:
            infrastructure-server:
              ansible_host: 10.8.8.100
              #IP used for communication between infra and kubernetes nodes, must be specified.
              cluster_ip: 10.8.8.100

        # This is group of hosts which are/will be part of Kubernetes cluster.
        kubernetes:
          children:
            # This is a group of hosts containing kubernetes worker nodes.
            kubernetes-node:
              hosts:
                kubernetes-node-1:
                  ansible_host: 10.8.8.101
                  #ip of the node that it uses for communication with k8s cluster.
                  cluster_ip: 10.8.8.101
                kubernetes-node-2:
                  ansible_host: 10.8.8.102
                  #ip of the node that it uses for communication with k8s cluster.
                  cluster_ip: 10.8.8.102
                kubernetes-node-3:
                  ansible_host: 10.8.8.103
                  #ip of the node that it uses for communication with k8s cluster.
                  cluster_ip: 10.8.8.103

            # Group of hosts containing etcd cluster nodes.
            # Defaults to infra.
            kubernetes-etcd:
              hosts:
                infrastructure-server

            # This is a group of hosts that are to be used as kubernetes control plane nodes.
            # This means they host kubernetes api server, controller manager and scheduler.
            # This example uses infra for this purpose, however note that any
            # other host could be used including kubernetes nodes.
            # cluster_ip needs to be set for hosts used as control planes.
            kubernetes-control-plane:
              hosts:
                infrastructure-server

        nfs-server:
          hosts:
            kubernetes-node-1

.. _oooi_installguide_config_appconfig:

application_configuration.yml
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Here, we will be interested in the following variables:

- ``resources_dir``
- ``resources_filename``
- ``aux_resources_filename``
- ``app_data_path``
- ``aux_data_path``
- ``app_name``
- ``timesync``

``'resource_dir'``, ``'resources_filename'`` and ``'aux_resources_filename'`` must correspond to the file paths on the *resource-host* (variable ``'resource_host'``), which is in our case the *install-server*.

The ``'resource_dir'`` should be set to ``'/data'``, ``'resources_filename'`` to ``'resources_package.tar'`` and ``'aux_resources_filename'`` to ``'aux_package.tar'``. The values should be the same as are in the `Installer packages`_ section.

``'app_data_path'`` is the absolute path on the *infra-node* to where the package ``'resources_package.tar'`` will be extracted and similarly ``'aux_data_path'`` is another absolute path for ``'aux_package.tar'``. Both the paths are fully arbitrary, but they should point to the filesystem with enough space - the storage requirement in `Overview table of the kubernetes cluster`_.

**NOTE:** As we mentioned in `Installer packages`_ - the auxiliary package is not mandatory and we will not utilize it in here either.

The ``'app_name'`` variable should be short and descriptive. We will set it simply to: ``onap``.

The ``'timesync'`` variable is optional and controls synchronisation of the system clock on hosts. It should be configured only if a custom NTP server is available and needed. Such a time authority should be on a host reachable from all installation nodes. If this setting is not provided then the default behavior is to setup NTP daemon on infra-node and sync all kube-nodes' time with it.

If you wish to provide your own NTP servers configure their IPs as follows::

    timesync:
      servers:
       - <ip address of NTP_1>
       - <...>
       - <ip address of NTP_N>

Another time adjustment related variables are ``'timesync.slewclock'`` and ``'timesync.timezone'`` .
First one can have value of ``'true'`` or ``'false'`` (default). It controls whether (in case of big time difference compared to server) time should be adjusted gradually by slowing down or speeding up the clock as required (``'true'``) or in one step (``'false'``)::

    timesync:
      slewclock: true

Second one controls time zone setting on host. It's value should be time zone name according to tz database names with ``'Universal'`` being the default one::

    timesync.
      timezone: UTC

``'timesync.servers'``, ``'timesync.slewclock'`` and ``'timesync.timezone'`` settings can be used independently.

Final configuration can resemble the following::

    resources_dir: /data
    resources_filename: resources_package.tar
    app_data_path: /opt/onap
    app_name: onap
    timesync:
      servers:
        - 192.168.0.1
        - 192.168.0.2
      slewclock: true
      timezone: UTC

.. _oooi_installguide_config_appconfig_overrides:

Helm chart value overrides
^^^^^^^^^^^^^^^^^^^^^^^^^^

In El Alto OOM charts are coming with all ONAP components disabled, this setting is also prepackaged within our sw_package.tar. Luckily there are multiple ways supported how to override this setting. It's also necessary for setting-up VIM specific entries and basically to configure any stuff with non default values.

First option is to use ``overrides`` key in ``application_configuration.yml``.
These settings will override helm values originally stored in ``values.yaml`` files in helm chart directories.

For example, the following lines could be appended to ``application_configuration.yml`` to set up managed openstack credentials for onap's so component::

    overrides:
      so:
        config:
          openStackUserName: "os_user"
          openStackRegion: "region_name"
          openStackKeyStoneUrl: "keystone_url"
          openStackEncryptedPasswordHere: "encrypted_password"

In addition or alternatively to that one can configure ``helm_override_files`` key, which is new feature implemented in Change-Id: I8b8ded38b39aa9a75e55fc63fa0e11b986556cb8.

.. _oooi_installguide_config_ssh:

SSH authentication
~~~~~~~~~~~~~~~~~~

We are almost finished with the configuration and we are close to start the installation, but we need to setup password-less login from *install-server* to the nodes.

You can use the ansible playbook ``'setup.yml'`` like this::

    $ ./run_playbook.sh -i inventory/hosts.yml setup.yml -u root --ask-pass

You will be asked for password per each node and the playbook will generate a unprotected ssh key-pair ``'~/.ssh/offline_ssh_key'``, which will be distributed to the nodes.

Another option is to generate a ssh key-pair manually. We strongly advise you to protect it with a passphrase, but for simplicity we will showcase generating of a private key without any such protection::

    $ ssh-keygen -N "" -f ~/.ssh/identity

The next step will be to distribute the public key to these nodes and from that point no password is needed::

    $ for ip in 100 101 102 103 ; do ssh-copy-id -i ~/.ssh/identity.pub root@10.8.8.${ip} ; done

This command behaves almost identically to the ``'setup.yml'`` playbook.

If you generated the ssh key manually then you can now run the ``'setup.yml'`` playbook like this and achieve the same result as in the first execution::

    $ ./run_playbook.sh -i inventory/hosts.yml setup.yml

This time it should not ask you for any password - of course this is very redundant, because you just distributed two ssh keys for no good reason.

We can finally edit and finish the configuration of the ``'hosts.yml'``:

- if you used the ``'setup.yml'`` playbook then you can just leave this line as it is::

    ansible_ssh_private_key_file: /root/.ssh/offline_ssh_key

- if you created a ssh key manually then change it like this::

    ansible_ssh_private_key_file: /root/.ssh/identity

-----

.. _oooi_installguide_install:

Part 3. Installation
--------------------

We should have the configuration complete and be ready to start the installation. The installation is done via ansible playbooks, which are run either inside a **chroot** environment (default) or from the **docker** container. If for some reason you want to run playbooks from the docker instead of chroot then you cannot use *infra-node* or any other *kube-node* as the *install-server* - otherwise you risk that installation will fail due to restarting of the docker service.

If you built your ``'sw'`` package well then there should be the file ``'ansible_chroot.tgz'`` inside the ``'docker'`` directory. If not then you must create it - to learn how to do that and to get more info about the scripts dealing with docker and chroot, go to `Appendix 1. Ansible execution/bootstrap`_

We will use the default chroot option so we don't need any docker service to be running.

Installation is actually very straightforward now::

    $ ./run_playbook.sh -i inventory/hosts.yml -e @application/application_configuration.yml site.yml

This will take a while so be patient.

``'site.yml'`` playbook actually runs in the order the following playbooks:

- ``upload_resources.yml``
- ``infrastructure.yml``
- ``rke.yml``
- ``application.yml``

----

.. _oooi_installguide_postinstall:

Part 4. Post-installation and troubleshooting
---------------------------------------------

After all of the playbooks are run successfully, it will still take a lot of time until all pods are up and running. You can monitor your newly created kubernetes cluster for example like this::

    $ ssh -i ~/.ssh/offline_ssh_key root@10.8.8.100 # tailor this command to connect to your infra-node
    $ watch -d -n 5 'kubectl get pods --all-namespaces'

Alternatively you can monitor progress with ``helm_deployment_status.py`` script located in offline-installer directory. Transfer it to infra-node and run::

    $ python helm_deployment_status.py -n <namespace_name> # namespace defaults to onap

To automatically verify functionality with healthchecks after deployment becomes ready or after timeout period expires, append ``-hp`` switch followed by the full path to the healthcheck script and ``--health-mode`` optional switch with appropriate mode supported by that script (``health`` by default, ``--help`` displays available modes)::

    $ python helm_deployment_status.py -hp <app_data_path>/<app_name>/helm_charts/robot/ete-k8s.sh --health-mode <healthcheck mode>

It is strongly recommended to tailor ``helm_deployment_status.py`` to your needs since default values might not be what you'd expect. The defaults can be displayed with ``--help`` switch.

Final result of installation varies based on number of k8s nodes used and distribution of pods. In some dev envs we quite frequently hit problems with not all pods properly deployed. In successful deployments all jobs should be in successful state.
This can be verified using ::

    $ kubectl get jobs -n <namespace>

If some of the job is hanging in some wrong end-state like ``'BackoffLimitExceeded'`` manual intervention is required to heal this and make also dependent jobs passing. More details about particular job state can be obtained using ::

    $ kubectl describe job -n <namespace> <job_name>

If manual intervention is required, one can remove failing job and retry helm install command directly, which will not launch full deployment but rather check current state of the system and rebuild parts which are not up & running. Exact commands are as follows ::

    $ kubectl delete job -n <namespace> <job_name>
    $ helm deploy <env_name> <helm_chart_name> --namespace <namespace_name>

    E.g. helm deploy dev local/onap --namespace onap

Once all pods are properly deployed and in running state, one can verify functionality e.g. by running onap healthchecks ::

    $ cd <app_data_path>/<app_name>/helm_charts/robot
    $ ./ete-k8s.sh onap health


-----

.. _oooi_installguide_appendix1:

Appendix 1. Ansible execution/bootstrap
---------------------------------------

There are two ways how to easily run the installer's ansible playbooks:

- If you already have or can install a docker then you can build the provided ``'Dockerfile'`` for the ansible and run playbooks in the docker container.
- Another way to deploy ansible is via chroot environment which is bundled together within this directory.

(Re)build docker image and/or chroot archive
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Inside the ``'docker'`` directory is the ``'Dockerfile'`` and ``'build_ansible_image.sh'`` script. You can run ``'build_ansible_image.sh'`` script on some machine with the internet connectivity and it will download all required packages needed for building the ansible docker image and for exporting it into a flat chroot environment.

Built image is exported into ``'ansible_chroot.tgz'`` archive in the same (``'docker'``) directory.

This script has two optional arguments:

#. ansible version
#. docker image name

**Note:** if optional arguments are not used, docker image name will be set to ``'ansible'`` by default.

Launching ansible playbook using chroot environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is the default and preferred way of running ansible playbooks in an offline environment as there is no dependency on docker to be installed on the system. Chroot environment is already provided by included archive ``'ansible_chroot.tgz'``.

It should be available in the ``'docker'`` directory as the end-result of the packaging script or after manual run of the ``'build_ansible_image.sh'`` script referenced above.

All playbooks can be executed via ``'./run_playbook.sh'`` wrapper script.

To get more info about the way how the ``'./run_playbook.sh'`` wrapper script should be used, run::

    $ ./run_playbook.sh

The main purpose of this wrapper script is to provide the ansible framework to a machine where it was bootstrapped without need of installing additional packages. The user can run this to display ``'ansible-playbook'`` command help::

    $ ./run_playbook.sh --help

Developers notes
~~~~~~~~~~~~~~~~

* There are two scripts which work in tandem for creating and running chroot
* First one can convert docker image into chroot directory
* Second script will automate chrooting (necessary steps for chroot to work and cleanup)
* Both of them have help - just run::

    $ cd docker
    $ ./create_docker_chroot.sh help
    $ ./run_chroot.sh help

Example usage::

    $ sudo su
    $ docker/create_docker_chroot.sh convert some_docker_image ./new_name_for_chroot
    $ cat ./new_name_for_chroot/README.md
    $ docker/run_chroot.sh execute ./new_name_for_chroot cat /etc/os-release 2>/dev/null

Launching ansible playbook using docker container (ALTERNATIVE APPROACH)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This option is here just to keep support for the older method which relies on a running docker service. For the offline deployment use the chroot option as indicated above.

You will not need ``'ansible_chroot.tgz'`` archive anymore, but the new requirement is a prebuilt docker image of ansible (based on the provided ``'Dockerfile'``). It should be available in your local docker repository (otherwise the default name ``'ansible'`` may fetch unwanted image from default registry!).

To trigger this functionality and to run ``'ansible-playbook'`` inside a docker container instead of the chroot environment, you must first set the ``ANSIBLE_DOCKER_IMAGE`` variable. The value must be a name of the built ansible docker image.

Usage is basically the same as with the default chroot way - the only difference is the existence of the environment variable::

    $ ANSIBLE_DOCKER_IMAGE=ansible ./run_playbook.sh --help

-----

.. _Build Guide: ./BuildGuide.rst
.. _El Alto requirements: https://onap.readthedocs.io/en/elalto/guides/onap-developer/settingup/index.html#installing-onap
.. _El Alto release: https://docs.onap.org/en/elalto/release/
.. _OOM ONAP: https://wiki.onap.org/display/DW/ONAP+Operations+Manager+Project
