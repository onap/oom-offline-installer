def test_dir(host):
    f = host.file('/cfg')
    assert f.exists
    assert f.is_directory


def test_simulated_hostname_file(host):
    f = host.file('/cfg/nginx.conf')
    assert f.exists


def test_nginx_container(host):
    c = host.docker('nginx-server')
    assert c.is_running
