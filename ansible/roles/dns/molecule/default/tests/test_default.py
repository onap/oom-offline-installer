def test_dir(host):
    f = host.file('/cfg')
    assert f.exists
    assert f.is_directory


def test_hostname_file(host):
    assert host.file('/cfg/simulated_hosts').exists


def test_dns_container(host):
    assert host.docker('dns-server').is_running
