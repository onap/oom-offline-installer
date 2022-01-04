import yaml


def test_prometheus_helm_package(host):
    assert host.file('/opt/onap/downloads/'
                     'kube-prometheus-stack-18.0.4.tgz').exists


def test_helm_values_file(host):
    y = None
    f = host.file('/opt/onap/kube_prometheus_values.yaml')
    assert f.exists
    assert f.is_file
    try:
        y = yaml.safe_load(f.content)
    except yaml.YAMLError:
        assert False
    assert y['grafana']['adminPassword'] == 'grafana'
    assert (y['grafana']['env']['GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH'] ==
            '/var/lib/grafana/dashboards/grafana_home.json')
    assert (y['grafana']['persistence']['storageClassName'] ==
            'kube-prometheus-grafana')
    assert (y['prometheus']['prometheusSpec']['storageSpec']
            ['volumeClaimTemplate']['spec']['storageClassName'] ==
            'kube-prometheus-prometheus')


def test_grafana_dashboards(host):
    assert host.file('/dockerdata-nfs/kube-prometheus/kube-prometheus-grafana/'
                     'dashboards/custom/grafana_dashboard.json').exists
    assert host.file('/dockerdata-nfs/kube-prometheus/kube-prometheus-grafana/'
                     'dashboards/grafana_home.json').exists
