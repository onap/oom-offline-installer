# Offline Kubernetes deployment with Ansible

This solution is generic offline deployment for Kubernetes which can host any
Kubernetes application in completely offline manner without internet connection.

It's developed for the purpose of hosting [ONAP](https://www.onap.org/) and proven
to work with that. ONAP is a very big Kubernetes application deployed by using
[Helm](https://helm.sh/) charts.

By default this solution supports deploying Kubernetes application with Helm charts.

## Ansible execution/bootstrap

There are two ways how to easily run our ansible playbooks.

If you already have or can install a docker then you can build the provided `Dockerfile` for the ansible and run playbooks in the docker container.

Another way to deploy ansible is via chroot environment which is bundled together within this directory.

### (Re)build docker image and/or chroot archive

Inside the docker directory is the `Dockerfile` and `build_ansible_image.sh` script. You can run `build_ansible_image.sh` script somewhere with internet connectivity and it will download all required packages needed for building the ansible docker image and for exporting it into flat chroot environment.

Note: git must be installed before this script is called

Built image is exported into `ansible_chroot.tgz` archive in the same (./docker) directory.

This script has two optional arguments:

1. ansible version
1. docker image name

Note: if optional arguments are not used, docker image name will be set to `ansible` by default.

### Launching ansible playbook using chroot environment

This is our default and preferred way of running ansible playbooks in an offline environment as there is no dependency on docker to be installed on the system. Chroot environment is already provided by included archive `ansible_chroot.tgz`.

It should be available in ./docker directory as the end-result of our packaging script or after manual running of `build_ansible_image.sh` referenced above.

All playbooks can be executed via `./run_playbook.sh` wrapper script.

To get more info about how the `./run_playbook.sh` wrapper script should be used, run:
```bash
./run_playbook.sh
```

The main purpose of this wrapper script is to provide ansible to machine where it was bootstrapped w/o need of installing additional packages, for displaying ansible-playbook command help one can run this following help command:
```bash
./run_playbook.sh --help
```

#### Developers notes from chroot approach

* There are two scripts which work in tandem for creating and running chroot
* First can convert docker image into chroot directory
* Second will automate chrooting (necessary steps for chroot to work and cleanup)
* Both of them have help - just run:

```bash
$ cd docker
$ ./create_docker_chroot.sh help
$ ./run_chroot.sh help
```

#### Example usage:

```
$ sudo su
$ docker/create_docker_chroot.sh convert some_docker_image ./new_name_for_chroot
$ cat ./new_name_for_chroot/README.md
$ docker/run_chroot.sh execute ./new_name_for_chroot cat /etc/os-release 2>/dev/null
```

### Launching ansible playbook using docker container (ALTERNATIVE APPROACH)

This option is here just to keep support for the older method which rely on a running docker service. For the offline deployment use the chroot option as indicated above.

You will not need `ansible_chroot.tgz` archive anymore, but the new requirement is a prebuilt docker image of ansible (based on our `Dockerfile`). It should be available in your local docker repository (otherwise the default name `ansible` may fetch unwanted image from default registry).

To trigger this functionality and run `ansible-playbook` inside a docker container instead of the chroot environment, you must first set the `ANSIBLE_DOCKER_IMAGE` variable. The value must be a name of the built ansible docker image - built using our provided `Dockerfile`.

Image name can be obtained again from `docker images` output.

```
E.g.
REPOSITORY                                 TAG                 IMAGE ID            CREATED             SIZE
ansible                                    latest              c44633617bfb        2 hours ago         127 MB
```

Usage is basically the same as with the default chroot way - the only difference is the existence of the env variable:

```bash
export ANSIBLE_DOCKER_IMAGE=ansible
./run_playbook.sh <args>
```

or in a single command

```bash
ANSIBLE_DOCKER_IMAGE=ansible ./run_playbook.sh <args>
```

---

## Playbooks

This chapter introduces all playbooks that each can be run independently, however
the order of running playbooks is implicitly fixed.

The complete offline deployment is handled by `site.yml` Ansible playbook.
This playbook contains imports for all the other playbooks needed to deploy
wanted Kubernetes application:
  - `upload_resources.yml`
  - `infrastructure.yml`
  - `rke.yml`
  - `application.yml` - this is an application related playbook

### Resource upload

Resource upload(nexus data, docker images, packages, etc.) is handled by playbook `upload_resources.yml`.

**Preconditions:**
  - setup nfs server for folder with resources (`resources.tar`) so it can be mounted on infrastructure server.

### Infrastructure setup

Infrastructure deployment consists of:
  - docker installed on all nodes
  - dnsmasq docker container setup and start
  - vncserver docker container setup and start
  - nexus3 docker container - consists of docker images for application, Rancher and other resources
  - nginx docker container - serves mainly as proxy for nexus, and also for providing other resources via HTTP/HTTPS

Infrastructure setup is handled by `infrastructure.yml` playbook.

**Preconditions**:
  - resources uploaded to infrastructure server (usually handled by `upload_resources.yml` playbook). All folders from resources should be located in directory defined in `{{ app_data_path }}` variable (e.g. `/opt/onap`).

### Kubernetes cluster deployment

Kubernetes cluster deployment is handled by `rke.yml` playbook.

**Preconditions**:
  - infrastructure deployed by running `infrastructure.yml` playbook

### Kubernetes application installation

Application installation is handled by `application.yml` playbook.

Application is dependent on resources:
  - images, files, etc. included in resources.tar handled by upload_resources.yml playbook.
  - Helm charts pointing to those images and files.
  - Application specific configuration

Binary resources must be handled to be in place already during packaging and that
is instructed in **HERE/TODO**.

Application Helm charts and configuration can also be packaged into the package itself and is then available on ./application folder. However it can also be
copied there after installer package is deployed and before installing the application.

Application Helm charts and configuration is better described in [application/README.md](./application/README.md)

**Preconditions**:
  - Kubernetes cluster must be up and running i.e. `rke.yml` playbook has been run.

## Running playbooks
To run ansible playbook call `run_playbook.sh` with same arguments as you would
call ansible-playbook.

Script `run_playbook.sh` must be executed from ansible directory to work correctly.

Example:
```bash
./run_playbook.sh -i application/hosts.yml playbook.yml
```

## Deployment

This chapter describes how to start whole deployment of offline solution from scratch
after offline software package is installed (untarred) to target machine from which
Ansible will be run towards the target servers. Target servers are already in place
and running.

After offline software package is untarred, locate the ansible directory in there
having this README file you are reading.

### Preparations

**SSH keys**:

In our playbooks we expects to have passwordless login to all ansible administrated nodes.
There is a helping playbook created to arrange that. Before setup playbook is executed
please insert IPs to inventory file as described below/

**Inventory**:

File **./inventory/hosts.yml** is an example inventory file that can be used as a
baseline. Copy inventory/hosts.yml file to ./application folder and modify needed
parts.

  - `./application/hosts.yml`:
    ```
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
              ansible_host: 10.8.8.9
              #IP used for communication between infra and kubernetes nodes, must be specified.
              cluster_ip: 10.8.8.9

        # This is group of hosts which are/will be part of Kubernetes cluster.
        kubernetes:
          hosts:
            kubernetes-node-1:
              ansible_host: 10.8.8.13
              #ip of the node that it uses for communication with k8s cluster.
              cluster_ip: 10.8.8.13

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
    ```



after setting up inventory file helping setup playbook can be executed to arrange passwordless
login to all nodes. It make sense to launch it just when root user can't access all nodes in
passwordless way using ssh key. If root user has access already with ssh key, please override
just ansible_ssh_private_key_file in inventory file accordingly and there is no need to launch
setup playbook.

If there is non-root user with ssh key access configured launch setup.yml in this way:

```bash
./run_playbook.sh -i application/hosts.yml setup.yml -u <user> -e ansible_ssh_private_key_file=<key>
```
e.g.
./run_playbook.sh -i application/hosts.yml setup.yml -u cloud-user -e ansible_ssh_private_key_file=/root/.ssh/id_rsa

in case of password login to nodes, run playbook with --ask-pass param

```bash
./run_playbook.sh -i application/hosts.yml setup.yml -u <user> --ask-pass
```

After running that playbook, passwordless login should be arranged for root user
using key ~/.ssh/offline_ssh_key which is preconfigured in inventory file.


**Deployment related configuration**:

Please check and review all options in `group_vars/all.yml` and `group_vars/infrastructure.yml`.

After inventory is setup and configuration is fine, all other playbooks (except application.yml) could be already be run and empty Kubernetes cluster (without application) could be setup.

**Application configuration**:

To deploy also application into Kubernetes, configure application configuration
needed by `application.yml` playbook.
See instructions on separate README.md file on [application/README.md](./application/README.md).

### Run Deployment

To deploy run:
```bash
./run_playbook.sh -i application/hosts.yml site.yml -e @application/application_configuration.yml
```
