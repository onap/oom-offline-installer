#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule

import requests
import json
import functools

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
  category:
    description:
      - The path in JSON API without the last element.
    required: false
    default: settings
    aliases:
      - rancher_category
      - api_category
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
  timeout:
    description:
      - How long in seconds to wait for a response before raising error
    required: false
    default: 10.0
"""


def _decorate_rancher_api_request(request_method):

    @functools.wraps(request_method)
    def wrap_request(*args, **kwargs):

        response = request_method(*args, **kwargs)

        if response.status_code != requests.codes.ok:
            response.raise_for_status()

        try:
            json_data = response.json()
        except Exception:
            json_data = None

        return json_data

    return wrap_request


@_decorate_rancher_api_request
def get_rancher_api_value(url, headers=None, timeout=10.0,
                          username=None, password=None):

    if username and password:
        return requests.get(url, headers=headers,
                            timeout=timeout,
                            allow_redirects=False,
                            auth=(username, password))
    else:
        return requests.get(url, headers=headers,
                            timeout=timeout,
                            allow_redirects=False)


@_decorate_rancher_api_request
def set_rancher_api_value(url, payload, headers=None, timeout=10.0,
                          username=None, password=None):

    if username and password:
        return requests.put(url, headers=headers,
                            timeout=timeout,
                            allow_redirects=False,
                            data=json.dumps(payload),
                            auth=(username, password))
    else:
        return requests.put(url, headers=headers,
                            timeout=timeout,
                            allow_redirects=False,
                            data=json.dumps(payload))


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
            category=dict(type='str', default='settings',
                          aliases=['rancher_category', 'api_category']),
            option=dict(type='str', required=True,
                        aliases=['name', 'key', 'settings']),
            value=dict(type='str', required=True),
            timeout=dict(type='float', default=10.0),
        ),
        supports_check_mode=True
    )

    rancher_url = module.params['rancher'].strip('/')
    rancher_option = module.params['option'].strip('/')
    rancher_category = module.params['category']
    rancher_value = module.params['value']
    rancher_timeout = module.params['timeout']
    # cattle_access_key = ''
    # cattle_secret_key = ''

    # Assemble API url
    request_url = rancher_url + '/v1/' + rancher_category + '/' \
        + rancher_option

    http_headers = {'Content-Type': 'application/json',
                    'Accept': 'application/json'}

    # API get current value
    try:
        json_response = get_rancher_api_value(request_url,
                                              headers=http_headers,
                                              timeout=rancher_timeout)
    except requests.HTTPError as e:
        module.fail_json(msg=str(e))
    except requests.Timeout as e:
        module.fail_json(msg=str(e))

    if not json_response:
        module.fail_json(msg='ERROR: BAD RESPONSE (GET) - no json value \
                         in the response')

    if is_valid_rancher_api_option(json_response):
        valid = True
        try:
            differs, payload = create_rancher_api_payload(json_response,
                                                          rancher_value)
        except ValueError:
            module.fail_json(msg='ERROR: INVALID JSON - missing json values \
                             in the response')
    else:
        valid = False

    if valid and differs and module.check_mode:
        # ansible dry-run mode
        changed = True
    elif valid and differs:
        # API set new value
        try:
            json_response = set_rancher_api_value(request_url,
                                                  payload,
                                                  headers=http_headers,
                                                  timeout=rancher_timeout)
        except requests.HTTPError as e:
            module.fail_json(msg=str(e))
        except requests.Timeout as e:
            module.fail_json(msg=str(e))

        if not json_response:
            module.fail_json(msg='ERROR: BAD RESPONSE (PUT) - no json value \
                             in the response')
        else:
            changed = True
    else:
        changed = False

    if changed:
        msg = "Option '%s' is now set to the new value: %s" \
            % (rancher_option, rancher_value)
    else:
        msg = "Option '%s' is unchanged." % (rancher_option)

    module.exit_json(changed=changed, msg=msg)


if __name__ == '__main__':
    main()
