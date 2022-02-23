import yaml


def test_override_file(host):
    y = None
    f = host.file("/override.yml")
    assert f.exists
    assert f.is_file
    try:
        y = yaml.safe_load(f.content)
    except yaml.YAMLError:
        assert False
    assert y['global']['cacert'] == 'this is dummy server certificate value\n'
