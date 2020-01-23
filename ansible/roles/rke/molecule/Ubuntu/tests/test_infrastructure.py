import os
import pytest
import json

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('infrastructure')


@pytest.mark.parametrize('filename', [
  '/root/.kube/config',
  '/opt/onap/cluster/cluster.yml',
  '/opt/onap/cluster/cluster.rkestate'])
def test_file_existence(host, filename):
    assert host.file(filename).exists


def test_rke_in_path(host):
    assert host.find_command('rke') == '/usr/local/bin/rke'


def test_rke_version_works(host):
    # Note that we need to cd to the cluster data dir first, really.
    assert host.run('cd /opt/onap/cluster && rke version').rc == 0


def test_nodes_ready(host):
    # Retrieve all node names.
    nodecmdres = host.run('kubectl get nodes -o name')
    assert nodecmdres.rc == 0
    nodes = nodecmdres.stdout.split('\n')
    for node in nodes:
        assert host.run(
          'kubectl wait --timeout=0 --for=condition=ready ' + node).rc == 0


def test_pods_ready(host):
    # Retrieve all pods from all namespaces.
    # Because we need pod and namespace name, we get full json representation.
    podcmdres = host.run('kubectl get pods --all-namespaces -o json')
    assert podcmdres.rc == 0
    pods = json.loads(podcmdres.stdout)['items']
    for pod in pods:
        # Each pod may be either created by a job or not.
        # In job case they should already be completed
        # when we are here so we ignore them.
        namespace = pod['metadata']['namespace']
        podname = pod['metadata']['name']
        condition = 'Ready'
        if len(pod['metadata']['ownerReferences']) == 1 and pod[
          'metadata']['ownerReferences'][0]['kind'] == 'Job':
            continue
        assert host.run(
          'kubectl wait --timeout=120s --for=condition=' + condition + ' -n ' +
          namespace + ' pods/' + podname).rc == 0
