import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('infrastructure-server')


@pytest.fixture
def group_vars(host):
    all_file = "file=group_vars/all.yml name=all"
    return host.ansible("include_vars", all_file)["ansible_facts"]["all"]


@pytest.mark.parametrize('dir', [
  'app_data_path',
  'aux_data_path'
])
def test_data_target_dirs(host, dir, group_vars):
    tested_dir = host.file(group_vars[dir])
    assert tested_dir.exists
    assert tested_dir.is_directory


@pytest.mark.parametrize('target_file', [
  'resource1.txt',
  'resource2.txt',
  'resource3.txt',
  'somedir/resource4.txt'
])
def test_transferred_resources_files(host, target_file, group_vars):
    tested_file = host.file(group_vars["app_data_path"] + "/" + target_file)
    assert tested_file.exists
    assert tested_file.is_file

    flag_file = \
        host.file(group_vars["app_data_path"] + "/" +
                  group_vars["resources_filename"] + "-uploaded")
    assert flag_file.exists
    assert flag_file.is_file


@pytest.mark.parametrize('target_file', [
  'auxdata'
])
def test_transferred_aux_resources_files(host, target_file, group_vars):
    tested_file = host.file(group_vars["aux_data_path"] + "/" + target_file)
    assert tested_file.exists
    assert tested_file.is_file

    flag_file = \
        host.file(group_vars["aux_data_path"] + "/" +
                  group_vars["aux_resources_filename"] + "-uploaded")
    assert flag_file.exists
    assert flag_file.is_file
