import yaml


def test_override_dir(host):
    d = host.file("/opt/moleculetestapp")
    assert d.exists
    assert d.is_directory


def test_override_file(host):
    y = None
    f = host.file("/opt/moleculetestapp/override.yaml")
    assert f.exists
    assert f.is_file
    try:
        y = yaml.safe_load(f.content)
    except yaml.YAMLError:
        assert False
    assert y['global']['cacert'] == 'this is dummy server certificate value\n'
