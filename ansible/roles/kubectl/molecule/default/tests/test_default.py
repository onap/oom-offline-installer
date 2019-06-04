import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_kubectl(host):
    assert host.file('/usr/local/bin/kubectl').exists
    assert host.run('kubectl').rc != 127
