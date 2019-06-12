import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.fixture
def chrony_conf_file(host, os_family):
    conf = host.ansible('include_vars', 'file=../../defaults/main.yml')[
            'ansible_facts']['chrony']['conf'][os_family]['config_file']
    return conf


@pytest.fixture
def os_family(host):
    osf = host.ansible("setup")['ansible_facts']['ansible_os_family']
    return osf


def test_chrony_conf_file_exists(host, chrony_conf_file):
    assert host.file(chrony_conf_file).exists, 'Config file not found!'


def test_chrony_service_running_enabled(host):
    assert host.service('chronyd').is_running, \
        'Chronyd service is not running!'
    assert host.service('chronyd').is_enabled, \
        'Chronyd service is not enabled!'


def test_ntp_synchronized(host, chrony_conf_file):
    assert host.file(chrony_conf_file).exists, 'Config file not found!'
    if host.file(chrony_conf_file).contains("server "):
        out = host.check_output('systemctl status chronyd')
        assert 'Selected source' in out, \
            'Chronyd did not synchronize with NTP server.'
    else:
        # Host acts as a time source
        pass
