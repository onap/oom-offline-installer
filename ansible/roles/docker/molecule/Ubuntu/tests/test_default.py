import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize('svc', [
    'docker'
])
def test_service(host, svc):
    service = host.service(svc)

    assert service.is_running
    assert service.is_enabled


def test_docker_daemon_file(host):
    f = host.file('/etc/docker/daemon.json')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    assert f.content_string == """{
    "log-opts": {
        "max-size": "100m", 
        "max-file": "3"
    }, 
    "dns": [
        "1.2.3.4"
    ], 
    "log-driver": "json-file"
}"""
