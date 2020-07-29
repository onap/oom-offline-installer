#!/usr/bin/python

DOCUMENTATION='''
---
module: rancher_k8s_environment
description:
  - This module will create or delete Kubernetes environment.
  - It will also delete other environments when variables are set accordingly.
notes:
  - It identifies environment only by name. Expect problems with same named environments.
  - All hosts running Kubernetes cluster should have same OS otherwise there
    is possibility of misbehavement.
options:
  server:
    required: true
    description:
      - Url of rancher server i.e. "http://10.0.0.1:8080".
  name:
    required: true
    descritpion:
      - Name of the environment to create/remove.
  descr:
    description:
      - Description of environment to create.
  state:
    description:
      - If "present" environment will be created or setup depending if it exists.
        With multiple environments with same name expect error.
        If "absent" environment will be removed. If multiple environments have same
        name all will be deleted.
    default: present
    choices: [present, absent]
  delete_not_k8s:
    description:
      - Indicates if environments with different orchestration than Kubernetes should
        be deleted.
    type: bool
    default: yes
  delete_other_k8s:
    description:
      - Indicates if environments with different name than specified should
        be deleted.
    type: bool
    default: no
  force:
    description:
      - Indicates if environment should be deleted and recreated.
    type: bool
    default: yes
  host_os:
    required: true
    description:
      - OS (family from ansible_os_family variable) of the hosts running cluster. If
        "RedHat" then datavolume fix will be applied.
        Fix described here:
          https://github.com/rancher/rancher/issues/10015
'''

import json
import time

import requests
from ansible.module_utils.basic import AnsibleModule



def get_existing_environments(rancher_address):
    req = requests.get('{}/v2-beta/projects'.format(rancher_address))
    envs = req.json()['data']
    return envs


def not_k8s_ids(environments):
    envs = filter(lambda x: x['orchestration'] != 'kubernetes', environments)
    return [env['id'] for env in envs]


def other_k8s_ids(environments, name):
    envs = filter(lambda x: x['orchestration'] == 'kubernetes' and x['name'] != name,
                  environments)
    return [env['id'] for env in envs]


def env_ids_by_name(environments, name):
    envs = filter(lambda x: x['name'] == name, environments)
    return [env['id'] for env in envs]


def env_info_by_id(environments, env_id):
    env = filter(lambda x: x['id'] == env_id, environments)
    return [{'id': x['id'], 'name': x['name']} for x in env][0]


def delete_multiple_environments(rancher_address, env_ids):
    deleted = []
    for env_id in env_ids:
        deleted.append(delete_environment(rancher_address, env_id))
    return deleted


def delete_environment(rancher_address, env_id):
    req = requests.delete('{}/v2-beta/projects/{}'.format(rancher_address, env_id))
    deleted = req.json()['data'][0]
    return {'id': deleted['id'],
            'name': deleted['name'],
            'orchestration': deleted['orchestration']}


def create_k8s_environment(rancher_address, name, descr):
    k8s_template_id = None
    for _ in range(10):
        k8s_template = requests.get(
            '{}/v2-beta/projecttemplates?name=Kubernetes'.format(rancher_address)).json()
        if k8s_template['data']:
            k8s_template_id = k8s_template['data'][0]['id']
            break
        time.sleep(3)
    if k8s_template_id is None:
        raise ValueError('Template for kubernetes not found.')
    body = {
        'name': name,
        'description': descr,
        'projectTemplateId': k8s_template_id,
        'allowSystemRole': False,
        'members': [],
        'virtualMachine': False,
        'servicesPortRange': None,
        'projectLinks': []
    }

    body_json = json.dumps(body)
    req = requests.post('{}/v2-beta/projects'.format(rancher_address), data=body_json)
    created = req.json()
    return {'id': created['id'], 'name': created['name']}


def get_kubelet_service(rancher_address, env_id):
    for _ in range(10):
        response = requests.get(
            '{}/v2-beta/projects/{}/services/?name=kubelet'.format(rancher_address,
                                                                   env_id))

        if response.status_code >= 400:
            # too early or too late for obtaining data
            # small delay will improve our chances to collect it
            time.sleep(1)
            continue

        content = response.json()

        if content['data']:
            return content['data'][0]

        # this is unfortunate, response from service api received but data
        # not available, lets try again
        time.sleep(5)

    return None


def fix_datavolume_rhel(rancher_address, env_id):
    kubelet_svc = get_kubelet_service(rancher_address, env_id)
    if kubelet_svc:
        try:
            data_volume_index = kubelet_svc['launchConfig']['dataVolumes'].index(
                '/sys:/sys:ro,rprivate')
        except ValueError:
            return 'Already changed'
        kubelet_svc['launchConfig']['dataVolumes'][
            data_volume_index] = '/sys/fs/cgroup:/sys/fs/cgroup:ro,rprivate'
        body = {
            'inServiceStrategy': {
                'batchSize': 1,
                'intervalMillis': 2000,
                'startFirst': False,
                'launchConfig': kubelet_svc['launchConfig'],
                'secondaryLaunchConfigs': []
            }
        }
        body_json = json.dumps(body)
        requests.post(
            '{}/v2-beta/projects/{}/services/{}?action=upgrade'.format(rancher_address,
                                                                       env_id,
                                                                       kubelet_svc[
                                                                           'id']),
            data=body_json)
        for _ in range(10):
            req_svc = requests.get(
                '{}/v2-beta/projects/{}/services/{}'.format(rancher_address, env_id,
                                                            kubelet_svc['id']))
            req_svc_content = req_svc.json()
            if 'finishupgrade' in req_svc_content['actions']:
                req_finish = requests.post(
                    req_svc_content['actions']['finishupgrade'])
                return {
                    'dataVolumes': req_finish.json()['upgrade']['inServiceStrategy'][
                        'launchConfig']['dataVolumes']}
            time.sleep(5)
    else:
        raise ValueError('Could not get kubelet service')


def create_registration_tokens(rancher_address, env_id):
    body = {'name': str(env_id)}
    body_json = json.dumps(body)
    response = requests.post(
        '{}/v2-beta/projects/{}/registrationtokens'.format(rancher_address, env_id,
                                                           data=body_json))
    for _ in range(10):
        tokens = requests.get(response.json()['links']['self'])
        tokens_content = tokens.json()
        if tokens_content['image'] is not None and tokens_content[
                'registrationUrl'] is not None:
            return {'image': tokens_content['image'],
                    'reg_url': tokens_content['registrationUrl']}
        time.sleep(3)
    return None


def get_registration_tokens(rancher_address, env_id):
    reg_tokens = requests.get(
        '{}/v2-beta/projects/{}/registrationtokens'.format(rancher_address, env_id))
    reg_tokens_content = reg_tokens.json()
    tokens = reg_tokens_content['data']
    if not tokens:
        return None
    return {'image': tokens[0]['image'], 'reg_url': tokens[0]['registrationUrl']}


def create_apikey(rancher_address, env_id):
    body = {
        'name': 'kubectl_env_{}'.format(env_id),
        'description': "Provides access to kubectl"
    }
    body_json = json.dumps(body)
    apikey_req = requests.post(
        '{}/v2-beta/apikey'.format(rancher_address, env_id, data=body_json))
    apikey_content = apikey_req.json()
    return {'public': apikey_content['publicValue'],
            'private': apikey_content['secretValue']}


def run_module():
    module = AnsibleModule(
        argument_spec=dict(
            server=dict(type='str', required=True),
            name=dict(type='str', required=True),
            descr=dict(type='str'),
            state=dict(type='str', choices=['present', 'absent'], default='present'),
            delete_other_k8s=dict(type='bool', default=False),
            delete_not_k8s=dict(type='bool', default=True),
            force=dict(type='bool', default=True),
            host_os=dict(type='str', required=True)
        )
    )

    params = module.params
    rancher_address = params['server']
    name = params['name']
    descr = params['descr']
    delete_not_k8s = params['delete_not_k8s']
    delete_other_k8s = params['delete_other_k8s']
    force = params['force']
    host_os = params['host_os']
    state = params['state']

    existing_envs = get_existing_environments(rancher_address)
    same_name_ids = env_ids_by_name(existing_envs, name)

    to_delete_ids = []
    changes = {}

    if delete_other_k8s:
        to_delete_ids += other_k8s_ids(existing_envs, name)

    if delete_not_k8s:
        to_delete_ids += not_k8s_ids(existing_envs)
    if force or state == 'absent':
        to_delete_ids += same_name_ids

    deleted = delete_multiple_environments(rancher_address, to_delete_ids)

    if deleted:
        changes['deleted'] = deleted
        if state == 'absent':
            module.exit_json(changed=True, deleted=changes['deleted'])
    else:
        if state == 'absent':
            module.exit_json(changed=False)

    if len(same_name_ids) > 1 and not force:
        module.fail_json(msg='Multiple environments with same name. '
                             'Use "force: yes" to delete '
                             'all environments with same name.')

    if same_name_ids and not force:
        changes['environment'] = env_info_by_id(existing_envs, same_name_ids[0])
        if host_os == 'RedHat':
            try:
                rhel_fix = fix_datavolume_rhel(rancher_address, same_name_ids[0])
                changes['rhel_fix'] = rhel_fix
            except ValueError as err:
                module.fail_json(
                    msg='Error: {} Try to recreate k8s environment.'.format(err))

        reg_tokens = get_registration_tokens(rancher_address, same_name_ids[0])
        if not reg_tokens:
            reg_tokens = create_registration_tokens(rancher_address, same_name_ids[0])
        changes['registration_tokens'] = reg_tokens

        apikey = create_apikey(rancher_address, same_name_ids[0])
        changes['apikey'] = apikey
        module.exit_json(changed=True, data=changes,
                         msg='New environment was not created. Only set up was done')
    try:
        new_env = create_k8s_environment(rancher_address, name, descr)
    except ValueError as err:
        module.fail_json(msg='Error: {} Try to recreate k8s environment.'.format(err))

    if host_os == 'RedHat':
        try:
            rhel_fix = fix_datavolume_rhel(rancher_address, new_env['id'])
            changes['rhel_fix'] = rhel_fix
        except ValueError as err:
            module.fail_json(msg='Error: {} Try to recreate k8s environment.'.format(
                err))

    reg_tokens = create_registration_tokens(rancher_address, new_env['id'])

    apikey = create_apikey(rancher_address, new_env['id'])

    changes['environment'] = new_env
    changes['registration_tokens'] = reg_tokens
    changes['apikey'] = apikey

    module.exit_json(changed=True, data=changes)


if __name__ == '__main__':
    run_module()
