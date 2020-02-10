import os
import pytest
import json

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
    print(f.content_string)
    json_data = json.loads(f.content_string)
    assert json_data["log-driver"] == "json-file"
    assert json_data["log-opts"]["max-size"] == "100m"
    assert json_data["log-opts"]["max-file"] == "3"
    assert json_data["dns"][0] == "1.2.3.4"
