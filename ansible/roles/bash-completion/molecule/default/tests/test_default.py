def test_bash_completion(host):
    assert host.package("bash-completion").is_installed


def test_bash_completion_kubectl(host):
    f = host.file('/etc/bash_completion.d/kubectl')
    assert f.exists
