# Application specific configuration

This directory is **empty** on purpose in git. Content in this folder is
placed on installer packaging time and can be modified by user on target
server where installer package is installed.

## Application configuration

All application related configuration variables are defined in file
`application_configuration.yml` in this folder. The name of configuration file
does not matter but it must be given to ansible run as command line variable file.

Example:
```
./run_playbook.sh application.yml -i application/hosts.yml -e @application/application_configuration.yml
```

## Application Helm charts

Application helm charts must be available on infra node before application playbook is executed.
That folder on infra node is specified within `app_helm_charts_infra_directory` variable.

Helm charts folder name is configured on `application_configuration.yml` file
with `app_helm_charts_directory` variable - it is the path on remote infrastructure server.

Example:
```
app_helm_charts_directory: /opt/application/helm_charts
```

It is expected that helm charts are available from packaging script as a part of installer SW package.
Such source directory of helm charts is specified by `app_helm_charts_install_directory` variable

Example:
```
app_helm_charts_install_directory: ansible/application/helm_charts/kubernetes
```

## Application specific roles

Installer supports optional custom pre and post install roles. Custom roles' code folders
need to be placed to this directory and name of those folders are configured in
application.yml with variable `application_pre_install_role` and `application_post_install_role`.

Example:
```
application_pre_install_role: "{{ project_configuration }}-patch-role"
```


## Inventory hosts

Ansible inventory file is least application specific but in practice example
inventory file in git ansible/inventory/hosts.yml cannot be directly used anyway
and at least ip addresses need to be changed according to target servers after
installer installation and before starting installer execution.

So it's better to place also hosts.yml to this application directory and edit it here.
