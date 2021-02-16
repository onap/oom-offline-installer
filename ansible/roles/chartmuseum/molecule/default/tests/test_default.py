import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_chartmuseum_dir(host):
    assert host.file("/chartmuseum").is_directory


def test_container_running(host):
    assert host.docker('chartmuseum').is_running
