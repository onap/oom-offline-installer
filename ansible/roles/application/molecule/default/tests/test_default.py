import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_helm_commands(host):
    fc = host.file('/tmp/helm_simu_output').content_string.strip()
    expected_content = """env
repo list
repo add local http://127.0.0.1:8879
deploy moleculetestapp local/moleculetestapp --namespace \
moleculetestapp -f /opt/moleculetestapp/helm_charts/onap/resources/\
overrides/onap-all.yaml -f /opt/moleculetestapp/override.yaml \
--timeout 1800s
env
repo list
repo add local http://127.0.0.1:8879
deploy moleculetestapp local/moleculetestapp --namespace \
moleculetestapp -f /opt/moleculetestapp/helm_charts/onap/resources/\
overrides/onap-all.yaml -f /opt/moleculetestapp/override.yaml \
--timeout 1800s"""
    expected_plugin_path = '/root/.local/share/helm/plugins/deploy/' +\
                           'deploy.sh'
    assert fc == expected_content
    assert host.file(expected_plugin_path).exists


def test_helm_override_file(host):
    fc = host.file('/opt/moleculetestapp/override.yaml').content_string.strip()
    expected_content = """global:
    cacert: 'this is dummy server certificate value

        '"""
    assert fc == expected_content
