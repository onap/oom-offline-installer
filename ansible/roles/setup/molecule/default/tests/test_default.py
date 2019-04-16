import os
import pytest
from os.path import expanduser

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.fixture
def get_vars(host):
    defaults_files = "file=../../defaults/main.yml name=role_defaults"
    ansible_vars = host.ansible(
        "include_vars",
        defaults_files)["ansible_facts"]["role_defaults"]
    return ansible_vars


def test_authorized_keys(host, get_vars):
    public_key_file = get_vars['offline_ssh_key_file_name'] + '.pub'
    with open(expanduser("~") + '/.ssh/' + public_key_file, 'r') as pkf:
        public_key_content = pkf.read().strip()

    f = host.file('/root/.ssh/authorized_keys')
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    assert oct(f.mode) == '0o600'
    assert f.content_string == public_key_content
