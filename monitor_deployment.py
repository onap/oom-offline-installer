#!/usr/bin/env python

#   COPYRIGHT NOTICE STARTS HERE

#   Copyright 2019 © Samsung Electronics Co., Ltd.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

#   COPYRIGHT NOTICE ENDS HERE


from __future__ import print_function
import sys
import argparse
import yaml
import requests
import subprocess
import datetime
from time import sleep
from os.path import expanduser
from itertools import chain
from pprint import pprint


requests.packages.urllib3.disable_warnings()

def gen_url(address, namespace, api, type, query_string=None):
    if type == 'pods':
        url = '/'.join([address, 'api/v1', 'namespaces', namespace, type])
    else:
        url = '/'.join([address, 'apis', api, 'namespaces', namespace, type])
    if query_string is None:
        return url
    return '?'.join([url, query_string])

def get_jobs(namespace, address):
    req = requests.get(gen_url(address, namespace, 'batch/v1', 'jobs'), verify = False)
    return req.json()['items']

def get_deployments(namespace, address):
    req = requests.get(gen_url(address, namespace, 'apps/v1', 'deployments'), verify = False)
    return req.json()['items']

def get_statefulsets(namespace, address):
    req = requests.get(gen_url(address, namespace, 'apps/v1', 'statefulsets'), verify = False)
    return req.json()['items']

def get_pods(namespace, address, query):
    req = requests.get(gen_url(address, namespace, 'core/v1', 'pods', query_string=query), verify = False)
    return req.json()['items']

def get_pods_by_parent(address, namespace, parent):
    return get_pods(namespace, address, 'labelSelector=app=' + parent)

def get_ready(data, jobs=False):
    if jobs:
        return filter(
            lambda x: x['status'].get('succeeded', 0) == x['spec']['completions'],
            data)
    return filter(lambda x: 'readyReplicas' in x['status'], data)

def get_not_ready(data, jobs=False):
    if jobs:
        return filter(
                lambda x: x['status'].get('succeeded', 0) != x['spec']['completions'],
                data)
    return filter(lambda x: 'unavailableReplicas' in x['status'], data)

def get_apps(data):
    return [x['metadata']['labels']['app'] for x in data]

def get_names(data):
    return [x['metadata']['name'] for x in data]

def get_pod_readiness(pod):
    return [x['status'] for x in pod['status']['conditions']
            if x['type'] == 'Ready'][0] == 'True'

def get_not_ready_pods(pods):
    return filter(lambda x: not get_pod_readiness(x), pods)

def analyze_k8s_controllers(resources_data, jobs=False):
    resources = {'ready_count': len(list(get_ready(resources_data, jobs)))}
    resources['not_ready_list'] = get_apps(get_not_ready(resources_data, jobs))
    resources['total_count'] = resources['ready_count'] + len(resources['not_ready_list'])

    return resources

def get_k8s_controllers(namespace, k8s_url):
    k8s_controllers = {}

    k8s_controllers['deployments'] = {'data': get_deployments(namespace, k8s_url)}
    k8s_controllers['deployments'].update(analyze_k8s_controllers(k8s_controllers['deployments']['data']))

    k8s_controllers['statefulsets'] = {'data': list(get_statefulsets(namespace, k8s_url))}
    k8s_controllers['statefulsets'].update(analyze_k8s_controllers(k8s_controllers['statefulsets']['data']))

    k8s_controllers['jobs'] = {'data': get_jobs(namespace, k8s_url)}
    k8s_controllers['jobs'].update(analyze_k8s_controllers(k8s_controllers['jobs']['data'], True))

    not_ready_controllers = chain.from_iterable(
            k8s_controllers[x]['not_ready_list'] for x in k8s_controllers)

    return k8s_controllers, list(not_ready_controllers)

def get_k8s_url(kube_config):
    # TODO: Get login info
    with open(kube_config) as f:
        config = yaml.load(f)
    # TODO: Support cluster by name
    return config['clusters'][0]['cluster']['server']

def exec_healthcheck(hp_script, namespace):
    try:
        hc = subprocess.check_output(
                ['sh', hp_script, namespace, 'health'],
                stderr=subprocess.STDOUT)
        return hc.returncode, hc.output
    except subprocess.CalledProcessError as err:
        return err.returncode, err.output

def create_ready_string(ready, total, prefix):
    return '{:12} {}/{}'.format(prefix, ready, total)

def print_status(verbosity, resources, not_ready_pods):
    ready_strings = []
    ready = {k: v['ready_count'] for k,v in resources.items()}
    count = {k: v['total_count'] for k,v in resources.items()}
    if verbosity > 0:
        ready_strings += [
                create_ready_string(ready[k], count[k], k.capitalize()) for k in ready
                ]
    total_ready = sum(ready.values())
    total_count = sum(count.values())
    ready_strings.append(create_ready_string(total_ready, total_count, 'Ready'))
    status_strings = ['\n'.join(ready_strings)]
    if verbosity > 1:
        if not_ready_pods:
            status_strings.append('\nWaiting for pods:\n{}'.format('\n'.join(not_ready_pods)))
        else:
            status_strings.append('\nAll pods are ready!')
    print('\n'.join(status_strings), '\n')

def check_readiness(k8s_url, namespace, verbosity):
        k8s_controllers, not_ready_controllers = get_k8s_controllers(namespace, k8s_url)

        if verbosity > 1:
            unready_pods = chain.from_iterable(
                   get_names(
                       get_pods_by_parent(k8s_url, namespace, x))
                   for x in not_ready_controllers)
        else:
            unready_pods = []

        print_status(verbosity, k8s_controllers, unready_pods)
        return not not_ready_controllers

def check_in_loop(k8s_url, namespace, max_time, sleep_time, verbosity):
    max_end_time = datetime.datetime.now() + datetime.timedelta(minutes=max_time)

    while datetime.datetime.now() < max_end_time:
        if check_readiness(k8s_url, namespace, verbosity):
            break
        sleep(sleep_time)

def parse_args():
    parser = argparse.ArgumentParser(description='Monitor ONAP deployment progress')
    parser.add_argument('-u', '--k8s-url', help='address of Kubernetes cluster')
    parser.add_argument('-c', '--kubeconfig',
            default=expanduser('~') + '/.kube/config',
            help='path to .kube/config file')
    parser.add_argument('-n', '--namespace', default='onap',
            help='Kubernetes namespace of ONAP')
    parser.add_argument('--no-helm', action='store_true', help='Do not check Helm')
    parser.add_argument('-hp', '--health-path', help='path to ONAP robot ete-k8s.sh')
    parser.add_argument('-w', '--check-frequency', default=300, type=int,
            help='time between readiness checks in seconds')
    parser.add_argument('-t', '--max-time', default=2, type=int,
            help='max time to run readiness checks in minutes')
    parser.add_argument('-1', '--single-run', action='store_true',
            help='run check loop only once')
    parser.add_argument('-v', '--verbosity', action='count', default=0,
            help='increase output verbosity')

    return parser.parse_args()

def main():
    args = parse_args()

    k8s_url = args.k8s_url if args.k8s_url is not None else get_k8s_url(args.kubeconfig)

    if args.single_run:
        check_readiness(k8s_url, args.namespace, args.verbosity)
    else:
        check_in_loop(k8s_url, args.namespace, args.max_time, args.check_frequency, args.verbosity)

    if args.health_path is not None:
        hc_rc, hc_output = exec_healthcheck(args.health_path, args.namespace)
        if args.verbosity > 1:
            print(hc_output)
        sys.exit(hc_rc)

if __name__ == '__main__':
    main()
