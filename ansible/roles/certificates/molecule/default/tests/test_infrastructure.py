import os
import pytest

import testinfra.utils.ansible_runner
from cryptography import x509

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('infrastructure')


@pytest.fixture
def group_vars(host):
    return host.ansible.get_variables()


@pytest.fixture
def crt_alt_names(host, group_vars):
    nexus_cert_file = host.file(group_vars["app_data_path"] + '/certs/'
                                + 'nexus_server.crt')
    x509_cert = x509.load_pem_x509_certificate(nexus_cert_file.content)
    san = x509_cert.extensions.get_extension_for_class(
          x509.SubjectAlternativeName)
    return san.value.get_values_for_type(x509.DNSName)


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
    with open("molecule/default/certs/" + cert_file) as local_cert_file:
        local_content = local_cert_file.read().strip()
    assert local_content == f.content_string.strip()


@pytest.mark.parametrize('alt_names', [
    'molecule.sim.host1',
    'molecule.sim.host2'
])
def test_subject_alt_name_valid(alt_names, crt_alt_names):
    assert alt_names in crt_alt_names
