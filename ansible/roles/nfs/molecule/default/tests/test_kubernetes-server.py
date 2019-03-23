import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('kubernetes-node-2')


def test_nfs_mount(host):
    mp = host.mount_point("/dockerdata-nfs")
    assert mp.exists
    assert mp.filesystem == "nfs"
    assert mp.device == "kubernetes-node-1:/dockerdata-nfs"
    assert host.file("/etc/fstab").\
        contains("kubernetes-node-1:/dockerdata-nfs /dockerdata-nfs nfs")
