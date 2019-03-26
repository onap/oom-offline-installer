#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule

import requests
import json

DOCUMENTATION = """
---
module: rancher1_api
short_description: Client library for rancher API
description:
  - This module modifies a rancher 1.6 using it's API (v1).
  - WIP, as of now it can only change a current value to a new one.

options:
  rancher:
    description:
      - The domain name or the IP address and the port of the rancher
        where API is exposed.
      - For example: http://10.0.0.1:8080
    required: true
    aliases:
      - server
      - rancher_url
      - rancher_api
      - api
      - url
  option:
    description:
      - The name of the settings option.
    required: true
    aliases:
      - name
      - key
      - settings
  value:
    description:
      - A new value to replace the current one.
    required: true
"""


def get_rancher_api_value(api_url, api_name='', timeout=10.0,
                          username=None, password=None):

    http_headers = {'Content-Type': 'application/json',
                    'Accept': 'application/json'}

    url = api_url.strip('/') + '/' + api_name

    if username and password:
        response = requests.get(url, headers=http_headers,
                                timeout=timeout,
                                allow_redirects=False,
                                auth=(username, password))
    else:
        response = requests.get(url, headers=http_headers,
                                timeout=10.0,
                                allow_redirects=False)

    if response.status_code != requests.codes.ok:
        response.raise_for_status()

    try:
        json_data = response.json()
    except Exception:
        json_data = None

    return json_data


def set_rancher_api_value(api_url, payload, api_name='', timeout=10.0,
                          username=None, password=None):

    http_headers = {'Content-Type': 'application/json',
                    'Accept': 'application/json'}

    url = api_url.strip('/') + '/' + api_name

    if username and password:
        response = requests.put(url, headers=http_headers,
                                timeout=timeout,
                                allow_redirects=False,
                                data=json.dumps(payload),
                                auth=(username, password))
    else:
        response = requests.put(url, headers=http_headers,
                                timeout=10.0,
                                allow_redirects=False,
                                data=json.dumps(payload))

    if response.status_code != requests.codes.ok:
        response.raise_for_status()

    try:
        json_data = response.json()
    except Exception:
        json_data = None

    return json_data


def create_rancher_api_payload(json_data, new_value):

    payload = {}

    try:
        api_id = json_data['id']
        api_activeValue = json_data['activeValue']
        api_name = json_data['name']
        api_source = json_data['source']
    except Exception:
        raise ValueError

    payload.update({"activeValue": api_activeValue,
                    "id": api_id,
                    "name": api_name,
                    "source": api_source,
                    "value": new_value})

    if api_activeValue != new_value:
        differs = True
    else:
        differs = False

    return differs, payload


def is_valid_rancher_api_option(json_data):

    try:
        api_activeValue = json_data['activeValue']
        api_source = json_data['source']
    except Exception:
        return False

    if api_activeValue is None and api_source is None:
        return False

    return True


def main():
    module = AnsibleModule(
        argument_spec=dict(
            rancher=dict(type='str', required=True,
                         aliases=['server',
                                  'rancher_api',
                                  'rancher_url',
                                  'api',
                                  'url']),
            option=dict(type='str', required=True,
                        aliases=['name', 'key', 'settings']),
            value=dict(type='str', required=True),
        ),
        supports_check_mode=True
    )

    rancher_url = module.params['rancher'].strip('/')
    rancher_option = module.params['option'].strip('/')
    rancher_value = module.params['value']
    rancher_timeout = 10.0
    # cattle_access_key = ''
    # cattle_secret_key = ''

    # Assemble API url
    rancher_url = rancher_url + '/v1/settings'
    #    module.fail_json(msg=str(err))
    #    module.fail_json(msg="Wrong usage of state, action and/or key/value")

    # API get current value
    try:
        json_response = get_rancher_api_value(rancher_url,
                                              rancher_option,
                                              timeout=rancher_timeout)
    except requests.HTTPError as e:
        module.fail_json(msg=str(e))
    except requests.Timeout as e:
        module.fail_json(msg=str(e))

    if not json_response:
        module.fail_json(msg='ERROR: BAD RESPONSE (GET) - no json value in the response')

    if is_valid_rancher_api_option(json_response):
        valid = True
        try:
            differs, payload = create_rancher_api_payload(json_response,
                                                          rancher_value)
        except ValueError:
            module.fail_json(msg='ERROR: INVALID JSON - missing json values in the response')
    else:
        valid = False

    if valid and differs and module.check_mode:
        # ansible dry-run mode
        changed = True
    elif valid and differs:
        # API set new value
        try:
            json_response = set_rancher_api_value(rancher_url,
                                                  payload,
                                                  rancher_option,
                                                  timeout=rancher_timeout)
        except requests.HTTPError as e:
            module.fail_json(msg=str(e))
        except requests.Timeout as e:
            module.fail_json(msg=str(e))

        if not json_response:
            module.fail_json(msg='ERROR: BAD RESPONSE (PUT) - no json value in the response')
        else:
            changed = True
    else:
        changed = False

    if changed:
        msg = "Option '%s' is now set to the new value: %s" % (rancher_option, rancher_value)
    else:
        msg = "Option '%s' is unchanged." % (rancher_option)

    module.exit_json(changed=changed, msg=msg)


if __name__ == '__main__':
    main()
