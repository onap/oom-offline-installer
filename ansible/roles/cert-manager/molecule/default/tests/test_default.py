def test_helm_value_file(host):
    f = host.file('/opt/onap/cert_manager.yaml')
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    assert f.content_string.strip() == "installCRDs: true"


def test_cmctl(host):
    f = host.file('/usr/local/bin/cmctl')
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    assert host.run('cmctl').rc == 0


def test_bash_completion(host):
    assert host.package("bash-completion").is_installed


def test_bash_completion_cmctl(host):
    f = host.file('/etc/bash_completion.d/cmctl')
    assert f.exists
