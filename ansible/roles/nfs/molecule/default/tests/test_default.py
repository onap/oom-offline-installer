import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize('distro,pkg', [
  ('centos', 'nfs-utils'),
  ('ubuntu', 'nfs-common'),
  ('ubuntu', 'nfs-kernel-server')
])
def test_pkg(host, distro, pkg):
    os = host.system_info.distribution
    if distro == os:
        package = host.package(pkg)
        assert package.is_installed
