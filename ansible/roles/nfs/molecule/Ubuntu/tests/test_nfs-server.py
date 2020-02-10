import os
import pytest

import testinfra
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('nfs-server')


@pytest.mark.parametrize('svc', [
    'rpcbind',
    'nfs-server'
])
def test_svc(host, svc):
    service = host.service(svc)

    assert service.is_running
    assert service.is_enabled


def test_exports(host):
    node2_ip = testinfra.get_host("docker://kubernetes-node-2").interface(
        "eth0").addresses[0]
    f = host.file("/etc/exports.d/dockerdata-nfs.exports")
    assert f.exists
    assert f.content_string == \
        """/dockerdata-nfs  """ + node2_ip + """(rw,sync,no_root_squash,no_subtree_check)"""  # noqa: E501
