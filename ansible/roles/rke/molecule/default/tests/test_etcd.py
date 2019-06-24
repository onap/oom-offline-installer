import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('kubernetes-etcd')


@pytest.mark.parametrize('container_name', [
  'etcd'])
def test_container_running(host, container_name):
    assert host.docker(container_name).is_running
