def test_helm_value_file(host):
    f = host.file('/opt/onap/cert_manager.yaml')
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    constr = f.content_string
    print(constr)
    assert constr == "installCRDs: true\n"


def test_cmctl(host):
    f = host.file('/usr/local/bin/cmctl')
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    assert host.run('cmctl').rc == 0


def test_bash_completion(host):
    f = host.file('/etc/bash_completion.d')
    f.exists
    f.is_directory


def test_bash_completion_cmctl(host):
    f = host.file('/etc/bash_completion.d/cmctl')
    assert f.exists
