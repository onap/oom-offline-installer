import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_firewall_service_disabled(host):
    distribution = host.system_info.distribution
    if distribution == "centos":
        svc = "firewalld"
    elif distribution == "ubuntu":
        svc = "ufw"
    service = host.service(svc)

    assert not service.is_running
    assert not service.is_enabled
