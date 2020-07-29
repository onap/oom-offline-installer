#!/usr/bin/env python
# -*- coding: utf-8 -*-

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
from subprocess import Popen,STDOUT,PIPE,check_output
import datetime
from time import sleep
from os.path import expanduser
from itertools import chain
import csv
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from base64 import b64decode
from tempfile import NamedTemporaryFile

def add_resource_kind(resources, kind):
    for item in resources:
        item['kind'] = kind
    return resources

def pods_by_parent(pods, parent):
    for pod in pods:
        if pod['metadata']['labels']['app'] == parent:
            yield pod

def k8s_controller_ready(k8s_controller):
    if k8s_controller['kind'] == 'Job':
        return k8s_controller['status'].get('succeeded', 0) == k8s_controller['spec']['completions']
    return k8s_controller['status'].get('readyReplicas', 0) == k8s_controller['spec']['replicas']

def get_not_ready(data):
    return [x for x in data if not k8s_controller_ready(x)]

def get_apps(data):
    return [x['metadata']['labels']['app'] for x in data]

def get_names(data):
    return [x['metadata']['name'] for x in data]

def pod_ready(pod):
    try:
        return [x['status'] for x in pod['status']['conditions']
                    if x['type'] == 'Ready'][0] == 'True'
    except (KeyError, IndexError):
        return False

def not_ready_pods(pods):
    for pod in pods:
        if not pod_ready(pod):
            yield pod

def analyze_k8s_controllers(resources_data):
    resources = {'total_count': len(resources_data)}
    resources['not_ready_list'] = get_apps(get_not_ready(resources_data))
    resources['ready_count'] = resources['total_count'] - len(resources['not_ready_list'])

    return resources

def get_k8s_controllers(k8s):
    k8s_controllers = {}

    k8s_controllers['deployments'] = {'data': k8s.get_resources(
        'apis/apps/v1', 'deployments')}
    k8s_controllers['deployments'].update(analyze_k8s_controllers(
        k8s_controllers['deployments']['data']))

    k8s_controllers['statefulsets'] = {'data': k8s.get_resources(
        'apis/apps/v1', 'statefulsets')}
    k8s_controllers['statefulsets'].update(analyze_k8s_controllers(
        k8s_controllers['statefulsets']['data']))

    k8s_controllers['jobs'] = {'data': k8s.get_resources(
        'apis/batch/v1', 'jobs')}
    k8s_controllers['jobs'].update(analyze_k8s_controllers(
        k8s_controllers['jobs']['data']))

    not_ready_controllers = chain.from_iterable(
            k8s_controllers[x]['not_ready_list'] for x in k8s_controllers)

    return k8s_controllers, list(not_ready_controllers)

def exec_healthcheck(hp_script, namespace, hp_mode):
    # spawn healthcheck script and redirect it's stderr to stdout
    hc = Popen(['sh',hp_script,namespace,hp_mode],stdout=PIPE,stderr=STDOUT)
    # Trace the output of subprocess until it has finished
    for line in iter(hc.stdout.readline, ''):
        print(line.strip())
    hc.poll() # set returncode in Popen object
    return hc.returncode

def check_readiness(k8s, verbosity):
    k8s_controllers, not_ready_controllers = get_k8s_controllers(k8s)

    # check pods only when it is explicitly wanted (judging readiness by deployment status)
    if verbosity > 1:
        pods = k8s.get_resources('api/v1', 'pods')
        unready_pods = chain.from_iterable(
               get_names(not_ready_pods(
                   pods_by_parent(pods, x)))
               for x in not_ready_controllers)
    else:
        unready_pods = []

    print_status(verbosity, k8s_controllers, unready_pods)
    return not not_ready_controllers

def check_in_loop(k8s, max_time, sleep_time, verbosity):
    max_end_time = datetime.datetime.now() + datetime.timedelta(minutes=max_time)
    ready = False
    while datetime.datetime.now() < max_end_time:
        ready = check_readiness(k8s, verbosity)
        if ready:
            return ready
        sleep(sleep_time)
    return ready

def check_helm_releases():
    helm = check_output(['helm', 'ls'])
    if helm == '':
        sys.exit('No Helm releases detected.')
    helm_releases = csv.DictReader(
            map(lambda x: x.replace(' ', ''), helm.split('\n')),
            delimiter='\t')
    failed_releases = [release['NAME'] for release in helm_releases
            if release['STATUS'] == 'FAILED']
    return helm, failed_releases


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

def parse_args():
    parser = argparse.ArgumentParser(description='Monitor ONAP deployment progress',
            formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--namespace', '-n', default='onap',
            help='Kubernetes namespace of ONAP')
    parser.add_argument('--server', '-s', help='address of Kubernetes cluster')
    parser.add_argument('--kubeconfig', '-c',
            default=expanduser('~') + '/.kube/config',
            help='path to .kube/config file')
    parser.add_argument('--health-path', '-hp', help='path to ONAP robot ete-k8s.sh')
    parser.add_argument('--health-mode', '-hm', default='health', help='healthcheck mode')
    parser.add_argument('--no-helm', action='store_true', help='Do not check Helm')
    parser.add_argument('--check-frequency', '-w', default=300, type=int,
            help='time between readiness checks in seconds')
    parser.add_argument('--max-time', '-t', default=120, type=int,
            help='max time to run readiness checks in minutes')
    parser.add_argument('--single-run', '-1', action='store_true',
            help='run check loop only once')
    parser.add_argument('-v', dest='verbosity', action='count', default=0,
            help='increase output verbosity, e.g. -vv is more verbose than -v')
    parser.add_argument('--no-ssl-auth', action='store_true',
            help='Disable SSL certificate based authentication while connecting to server')

    return parser.parse_args()

class Kubernetes:
    '''Class exposing get_resources() routine for connecting to kube API.
       It keeps all attributes required by that call as an internal
       object state.'''

    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

    def __init__(self,args):

        self.config = args.kubeconfig
        self.url = args.server if args.server is not None else \
                   self._get_k8s_url()
        self.no_ssl_auth = args.no_ssl_auth
        self.certs = self._get_k8s_certs() if not self.no_ssl_auth else {}
        self.namespace = args.namespace

        # Setup tmp file with ca chain only if certs were gathered successfully
        # and --no-ssl-auth wasn't set
        if self.certs and not self.no_ssl_auth:
            self._setup_cert_files()

    def get_resources(self, api, kind):
        '''Performs actual API call'''
        url = '/'.join([self.url, api, 'namespaces', self.namespace, kind])
        try:
            if self.no_ssl_auth:
                req = requests.get(url, verify=False)
            else:
                req = requests.get(url, verify=self.crt_tmp_file.name, cert=self.crt_tmp_file.name)
        except requests.exceptions.ConnectionError:
            sys.exit('Error: Could not connect to {}'.format(self.url))
        if req.status_code == 200:
            json = req.json()
            # kind is <resource>List in response so [:-4] removes 'List' from value
            return add_resource_kind(json['items'], json['kind'][:-4])
        elif (req.status_code == 401):
            sys.exit('Error: Server replied with "401 Unauthorized" while making connection')
        else:
            sys.exit("Error: There's been an unspecified issue while making a request to the API")

    def _setup_cert_files(self):
        '''Helper funtion to setup named file for requests.get() call
           in self.get_resources() which is able read certificate only
           from file'''
        ca_chain = NamedTemporaryFile()
        for crt in self.certs.values():
            ca_chain.write(crt)
        ca_chain.read() # flush the file buffer
        self.crt_tmp_file = ca_chain

    def _get_k8s_url(self):
        # TODO: Get login info
        with open(self.config) as f:
            config = yaml.load(f)
        # TODO: Support cluster by name
        return config['clusters'][0]['cluster']['server']

    def _get_k8s_certs(self):
        '''Helper function to read and decode certificates from kube config'''
        with open(self.config) as f:
            config = yaml.load(f)
        certs = {}
        try:
            certs.update(dict(ca_cert=b64decode(
              config['clusters'][0]['cluster']['certificate-authority-data'])))
            certs.update(dict(client_cert=b64decode(
              config['users'][0]['user']['client-certificate-data'])))
            certs.update(dict(client_key=b64decode(
              config['users'][0]['user']['client-key-data'])))
        except KeyError:
            print('Warning: could not get Kubernetes config for certificates. ' \
                      'Turning off SSL authentication.')
            self.no_ssl_auth = True
        return certs

def main():
    args = parse_args()

    if not args.no_helm:
        try:
            helm_output, failed_releases = check_helm_releases()
            if failed_releases:
                print('Deployment of {} failed.'.format(','.join(failed_releases)))
                sys.exit(1)
            elif args.verbosity > 1:
                print(helm_output)
        except IOError as err:
            sys.exit(err.strerror)

    k8s = Kubernetes(args)

    ready = False
    if args.single_run:
        ready = check_readiness(k8s, args.verbosity)
    else:
        if not check_in_loop(k8s, args.max_time, args.check_frequency, args.verbosity):
            # Double-check last 5 minutes and write verbosely in case it is not ready
            ready = check_readiness(k8s, 2)

    if args.health_path is not None:
        hc_rc = exec_healthcheck(args.health_path, args.namespace, args.health_mode)
        if hc_rc:
            sys.exit(hc_rc)

    if not ready:
        sys.exit('Deployment is not ready')

if __name__ == '__main__':
    main()
