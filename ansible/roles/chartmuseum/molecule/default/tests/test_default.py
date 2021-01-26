import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_chartmuseum(host):
    ansible_vars = host.ansible.get_variables()
    p = host.process.get(comm="chartmuseum")
    assert 'chartmuseum --storage local --storage-local-rootdir /opt/' +\
           ansible_vars['app_name'] + '/chartmuseum -port ' +\
           ansible_vars['chartmuseum_port'] in p.args
    assert host.file("/opt/" + ansible_vars['app_name'] +
           "/chartmuseum").is_directory
