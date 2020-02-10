import os

import testinfra
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('kubernetes-node-2')


def test_nfs_mount(host):
    node1_ip = testinfra.get_host("docker://kubernetes-node-1").interface(
        "eth0").addresses[0]
    mp = host.mount_point("/dockerdata-nfs")
    assert mp.exists
    assert mp.filesystem == "nfs" or mp.filesystem == "nfs4"
    assert mp.device == node1_ip + ":/dockerdata-nfs"
    assert host.file("/etc/fstab").\
        contains(node1_ip + ":/dockerdata-nfs /dockerdata-nfs nfs")
