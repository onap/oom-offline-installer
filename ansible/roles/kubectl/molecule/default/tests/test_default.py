def test_kubectl(host):
    assert host.file('/usr/local/bin/kubectl').exists
    assert host.run('kubectl').rc != 127
