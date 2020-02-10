import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('infrastructure-server')


def test_onap_repo(host):
    os = host.system_info.distribution
    if os == "centos":
        fc = host.file('/etc/yum.repos.d/moleculetestapp.repo').content_string
        expected_content = """[moleculetestapp]
baseurl = file:///opt/moleculetestapp/pkg/rpm
enabled = 1
gpgcheck = 0
name = MOLECULETESTAPP offline repository"""
        assert fc == expected_content
    elif os == "ubuntu":
        fc = host.file('/etc/apt/sources.list.d/moleculetestapp.list')
        fc = fc.content_string
        ec = "deb [trusted=yes] file:///opt/moleculetestapp/pkg/deb ./"
        assert fc == ec
