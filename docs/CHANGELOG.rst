CHANGELOG
=========

-----

2022-04-19
----------

- RKE upgrade to 1.3.8
- Kubernetes version deployed by RKE has been upgraded to v1.22.7
- Added provisioning of the Kubernetes Strimzi Kafka Operator

2022-02-18
----------

- Add support for ONAP services monitoring (leverages Prometheus ServiceMonitor objects)

2022-01-21
----------

- Add support in download script for leveraging docker mirroring registry for images from private repositories

2021-11-25
----------

- Dropped support for obsoleted Helm v2

2021-11-16
----------

- Added support for provisioning the cert-manager (https://cert-manager.io/)
- Added cmctl CLI management utility for cert-manager

2021-10-27
----------

- Upgraded Helm release to 3.6.3


2021-09-30
----------

- Add support in cicdansible for docker_storage_size heat stack parameter for setting custom docker storage volume size on nodes

2021-09-24
----------

- Upgrade supported OS to RedHat/CentOS 7.9

2021-09-17
----------

- Added provisioning of a config file containing resources dir full path


2021-09-16
----------

- A custom Grafana Home dashboard is added

2021-09-15
----------

- Default Grafana's password was changed to "grafana"

2021-09-13
----------

- Kubernetes Dashboard has been upgraded to v2.3.1

2021-09-09
----------

- Kube Prometheus Stack has been upgraded to 18.0.4

2021-09-07
----------

- Upgraded Helm release to 3.5.2

2021-09-02
----------

- RKE upgrade to 1.3.0
- Kubernetes version deployed by RKE has been upgraded to v1.19.14
- kubectl upgrade to 1.19.14

2021-06-29
----------

- Added an option to turn on Helm verbose output in helm-healer script

2021-06-24
----------

- Helm v2 specific code was abandoned
- Added support for provisioning Kube Prometheus Stack
