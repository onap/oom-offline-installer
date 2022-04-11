def test_helm_value_file(host):
    f = host.file('/opt/onap/strimzi_kafka.yaml')
    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
    assert f.content_string.strip() == "watchAnyNamespace: true"
