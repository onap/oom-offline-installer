# Application specific configuration

This directory is **empty** on purpose in git. Content in this folder is
populated packaging time (see package.sh/package.conf) and can be modified if needed
also on target server where package is installed.

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

There is a good default value for this variable and if not changed, installer will handle
Helm charts transfer from packaging up to the target infra server.

## Application specific roles

Installer supports optional custom pre and post install roles. Custom roles' code folders
are placed to this directory at packaging time and name of those folders are configured in
application.yml with variable `application_pre_install_role` and `application_post_install_role`.

Example:
```
application_pre_install_role: "{{ app_name }}-patch-role"
```

## Inventory hosts

Ansible inventory file is least application specific but in practice example
inventory file in git ansible/inventory/hosts.yml cannot be directly used anyway
and at least ip addresses need to be changed according to target servers after
installer installation and before starting installer execution.

So it's better to place also hosts.yml to this application directory and edit it here.
That can be done either at packaging time same way as application_configuration.yml
or after package has been installed to server where ansible process are run just
before lauching any playbooks.
