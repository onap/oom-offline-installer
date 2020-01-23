import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('infrastructure')


@pytest.fixture
def group_vars(host):
    all_file = "file=group_vars/all.yml name=all"
    return host.ansible("include_vars", all_file)["ansible_facts"]["all"]


@pytest.mark.parametrize('cert_file', [
    'nexus_server.crt',
    'nexus_server.csr',
    'nexus_server.key',
    'rootCA.crt',
    'rootCA.csr',
    'rootCA.key'
])
def test_generated_cert_files_copied_to_infra(host, cert_file, group_vars):
    f = host.file(group_vars["app_data_path"] + '/certs/' + cert_file)
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'

    # Verify cert files content locally is as in node
    with open("certs/" + cert_file) as local_cert_file:
        local_content = local_cert_file.read().strip()
    assert local_content == f.content_string
