def test_dir(host):
    f = host.file('/nexus_data')
    assert f.exists
    assert f.is_directory
    assert f.uid == 200
    assert f.gid == 200


def test_nexus_container(host):
    c = host.docker('nexus')
    assert c.is_running
