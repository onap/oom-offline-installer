import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_helm_commands(host):
    fc = host.file('/tmp/helm_simu_output').content_string
    helm_release = host.ansible.get_variables()['helm_version']
    if helm_release == 'v2':
        expected_content = """home
init --upgrade --skip-refresh
version --tiller-connection-timeout 10
repo list
serve
repo list
repo add local http://127.0.0.1:8879
deploy moleculetestapp local/moleculetestapp --namespace \
moleculetestapp -f /opt/moleculetestapp/helm_charts/onap/resources/\
overrides/onap-all.yaml -f /opt/moleculetestapp/override.yaml \
--timeout 1800"""
    elif helm_release == 'v3':
        expected_content = """env
deploy moleculetestapp local/moleculetestapp --namespace \
moleculetestapp -f /opt/moleculetestapp/helm_charts/onap/resources/\
overrides/onap-all.yaml -f /opt/moleculetestapp/override.yaml \
--timeout 1800"""
    assert fc == expected_content


def test_helm_override_file(host):
    fc = host.file('/opt/moleculetestapp/override.yaml').content_string
    expected_content = """global:
    cacert: 'this is dummy server certificate value

        '"""
    assert fc == expected_content
