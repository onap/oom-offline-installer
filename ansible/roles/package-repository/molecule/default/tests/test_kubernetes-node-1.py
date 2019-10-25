import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('kubernetes-node-1')


def test_onap_repo(host):
    fc = host.file('/etc/yum.repos.d/moleculetestapp.repo').content_string
    expected_content = """[moleculetestapp]
baseurl = http://repo.infra-server/rpm
enabled = 1
gpgcheck = 0
name = MOLECULETESTAPP offline repository"""
    assert fc == expected_content
