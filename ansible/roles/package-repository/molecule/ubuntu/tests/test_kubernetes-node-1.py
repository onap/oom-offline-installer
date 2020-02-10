import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('kubernetes-node-1')


def test_onap_repo(host):
    fc = host.file('/etc/apt/sources.list.d/moleculetestapp.list')
    fc = fc.content_string
    ec = "deb [trusted=yes] http://repo.infra-server/deb stable main"
    assert fc == ec
