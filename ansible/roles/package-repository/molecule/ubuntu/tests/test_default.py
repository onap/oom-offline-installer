import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_etc_resolv_conf_file(host):
    f = host.file('/etc/resolv.conf')
    assert f.contains("nameserver 6.5.4.3")
