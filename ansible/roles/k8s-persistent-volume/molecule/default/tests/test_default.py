import json


def test_k8s_pv(host):
    configs = {
                "kube-prometheus-prometheus": {
                    "size": "20Mi",
                    "hostPath": ("/dockerdata-nfs/kube-prometheus"
                                 "/kube-prometheus-prometheus")},
                "kube-prometheus-grafana": {
                    "size": "25Mi",
                    "hostPath": ("/dockerdata-nfs/kube-prometheus/"
                                 "kube-prometheus-grafana")}
    }
    k8s_response_json = json.loads(
            host.run('kubectl get pv -ojson').stdout)['items']
    assert len(k8s_response_json) == 2
    for n in k8s_response_json:
        name = n['metadata']['name']
        assert n['spec']['capacity']['storage'] == configs[name]['size']
        assert n['spec']['hostPath']['path'] == configs[name]['hostPath']


def test_pv_path(host):
    fpp = host.file("/dockerdata-nfs/kube-prometheus/"
                    "kube-prometheus-prometheus")
    fpg = host.file("/dockerdata-nfs/kube-prometheus/kube-prometheus-grafana")
    assert fpp.exists
    assert fpp.is_directory
    # 1000 u and 2000 g
    assert fpp.uid == 1000
    assert fpp.gid == 2000
    assert fpg.exists
    assert fpg.is_directory
