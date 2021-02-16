import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('infrastructure')


@pytest.mark.parametrize('filename', [
  '/root/.kube/config',
  '/opt/onap/cluster/cluster.yml',
  '/opt/onap/cluster/kubernetes-dashboard.yml',
  '/opt/onap/cluster/k8s-dashboard-user.yml',
  '/opt/onap/cluster/kube_config_cluster.yml'])
def test_file_existence(host, filename):
    assert host.file(filename).exists


def test_rke_in_path(host):
    assert host.find_command('rke') == '/usr/local/bin/rke'


def test_rke_version_works(host):
    # Note that we need to cd to the cluster data dir first, really.
    assert host.run('cd /opt/onap/cluster && rke').rc == 0
