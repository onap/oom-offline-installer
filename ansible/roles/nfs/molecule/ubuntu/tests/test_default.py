import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize('pkg', [
  'nfs-common',
  'nfs-kernel-server'
])
def test_pkg(host, pkg):
    package = host.package(pkg)

    assert package.is_installed
