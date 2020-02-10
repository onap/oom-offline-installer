import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize('cert_file', [
    'rootCA.crt'
])
def test_cert_file_installed(host, cert_file):
    os = host.system_info.distribution
    if os == "ubuntu":
        f = host.file('/usr/local/share/ca-certificates/' + cert_file)

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
