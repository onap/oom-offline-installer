import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('kubernetes')


def test_registry_access(host):
    assert host.run(
      'docker login -u admin -p admin123 nexus3.onap.org:10001').rc == 0
