Cert-manager provisioning role
==============================

Deploys cert-manager (https://cert-manager.io/) onto Kubernetes cluster into its own, separate namespace.

Requirements
------------

cert-manager tgz package is expected to exists in ``app_data_path/downloads`` directory prior to running this role.

Role Variables
--------------

- cert\_manager\_version (group\_vars) - version string of cert-manager to deploy (a.b.c)
- cert\_manager.k8s\_namespace (role's defaults) - namespace name to install cert-manager into
- cert\_manager.helm\_release\_name (role's defaults) - Helm release name for the chart
- cert\_manager.helm\_timeout (role's defaults) - helm install timeout
- cert\_manager.helm\_values\_file (role's defaults) - dst path for the yaml file containing cert-manager helm values
- cert\_manager.helm\_values (role's defaults) - dict of helm values for the cert-manager chart

Dependencies
------------

Ansible's community.kubernetes.helm module is required to play this role.
