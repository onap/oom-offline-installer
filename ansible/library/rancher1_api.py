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
  - It supports some rancher features by the virtue of a 'mode'.
  - 'modes' hide from you some necessary cruft and expose you to the only
    important and interestig variables wich must be set. The mode mechanism
    makes this module more easy to use and you don't have to create an
    unnecessary boilerplate for the API.
  - Only a few modes are/will be implemented so far - as they are/will be
    needed. In the future the 'raw' mode can be added to enable you to craft
    your own API requests, but that would be on the same level of a user
    experience as running curl commands, and because the rancher 1.6 is already
    obsoleted by the project, it would be a wasted effort.
options:
  rancher:
    description:
      - The domain name or the IP address and the port of the rancher
        where API is exposed.
      - For example: http://10.0.0.1:8080
    required: true
    aliases:
      - server
      - rancher_server
      - rancher_api
      - api
  account_key:
    description:
      - The public and secret part of the API key-pair separated by colon.
      - You can find all your keys in web UI.
      - For example:
        B1716C4133D3825051CB:3P2eb3QhokFKYUiXRNZLxvGNSRYgh6LHjuMicCHQ
    required: false
  mode:
    description:
      - A recognized mode how to deal with some concrete configuration task
        in rancher API to ease the usage.
      - The implemented modes so far are:
        'settings':
            Many options under <api_server>/v1/settings API url and some can
            be seen also under advanced options in the web UI.
        'access_control':
            It setups user and password for the account (defaults to 'admin')
            and it enables the local authentication - so the web UI and API
            will require username/password (UI) or apikey (API).
    required: true
    aliases:
      - rancher_mode
      - api_mode
    choices:
      - settings
      - access_control
  data:
    description:
      - Dictionary with key/value pairs. The actual names and meaning of pairs
        depends on the used mode.
      - 'settings' mode:
        option: Option/path in JSON API (url).
        value: A new value to replace the current one.
      - 'access_control' mode:
        None - not yet implemented - placeholder only.
    required: true
  timeout:
    description:
      - How long in seconds to wait for a response before raising error
    required: false
    default: 10.0
"""

default_timeout = 10.0


class ModeError(Exception):
    pass


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
def get_rancher_api_value(url, headers=None, timeout=default_timeout,
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
def set_rancher_api_value(url, payload, headers=None, timeout=default_timeout,
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


def create_rancher_api_url(server, mode, option):
    request_url = server.strip('/') + '/v1/'

    if mode == 'raw':
        request_url += option.strip('/')
    elif mode == 'settings':
        request_url += 'settings/' + option.strip('/')
    elif mode == 'access_control':
        request_url += option.strip('/')

    return request_url


def get_keypair(keypair):
    if keypair:
        keypair = keypair.split(':')
        if len(keypair) == 2:
            return keypair[0], keypair[1]

    return None, None


def mode_settings(api_url, data=None, headers=None, timeout=default_timeout,
                  access_key=None, secret_key=None, dry_run=False):

    def is_valid_rancher_api_option(json_data):

        try:
            api_activeValue = json_data['activeValue']
            api_source = json_data['source']
        except Exception:
            return False

        if api_activeValue is None and api_source is None:
            return False

        return True

    def create_rancher_api_payload(json_data, new_value):

        payload = {}
        differs = False

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

        return differs, payload

    # check if data contains all required fields
    try:
        if not isinstance(data['option'], str) or data['option'] == '':
            raise ModeError("ERROR: 'option' must contain a name of the \
                            option")
    except KeyError:
        raise ModeError("ERROR: Mode 'settings' requires the field: 'option': \
                        %s" % str(data))
    try:
        if not isinstance(data['value'], str) or data['value'] == '':
            raise ModeError("ERROR: 'value' must contain a value")
    except KeyError:
        raise ModeError("ERROR: Mode 'settings' requires the field: 'value': \
                        %s" % str(data))

    # assemble request URL
    request_url = api_url + 'settings/' + data['option'].strip('/')

    # API get current value
    try:
        json_response = get_rancher_api_value(request_url,
                                              username=access_key,
                                              password=secret_key,
                                              headers=headers,
                                              timeout=timeout)
    except requests.HTTPError as e:
        raise ModeError(str(e))
    except requests.Timeout as e:
        raise ModeError(str(e))

    if not json_response:
        raise ModeError('ERROR: BAD RESPONSE (GET) - no json value in the \
                        response')

    if is_valid_rancher_api_option(json_response):
        valid = True
        try:
            differs, payload = create_rancher_api_payload(json_response,
                                                          data['value'])
        except ValueError:
            raise ModeError('ERROR: INVALID JSON - missing json values in \
                            the response')
    else:
        valid = False

    if valid and differs and dry_run:
        # ansible dry-run mode
        changed = True
    elif valid and differs:
        # API set new value
        try:
            json_response = set_rancher_api_value(request_url,
                                                  payload,
                                                  username=access_key,
                                                  password=secret_key,
                                                  headers=headers,
                                                  timeout=timeout)
        except requests.HTTPError as e:
            raise ModeError(str(e))
        except requests.Timeout as e:
            raise ModeError(str(e))

        if not json_response:
            raise ModeError('ERROR: BAD RESPONSE (PUT) - no json value in \
                            the response')
        else:
            changed = True
    else:
        changed = False

    if changed:
        msg = "Option '%s' is now set to the new value: %s" \
            % (data['option'], data['value'])
    else:
        msg = "Option '%s' is unchanged." % (data['option'])

    return changed, msg


def mode_handler(server, rancher_mode, data=None, timeout=default_timeout,
                 account_key=None, dry_run=False):

    changed = False
    msg = 'UNKNOWN: UNAPPLICABLE MODE'

    # check API key-pair
    if account_key:
        access_key, secret_key = get_keypair(account_key)
        if not (access_key and secret_key):
            raise ModeError('ERROR: INVALID API KEY-PAIR')

    # all requests share these headers
    http_headers = {'Content-Type': 'application/json',
                    'Accept': 'application/json'}

    # assemble API url
    api_url = server.strip('/') + '/v1/'

    if rancher_mode == 'settings':
        changed, msg = mode_settings(api_url, data=data,
                                     headers=http_headers,
                                     timeout=timeout,
                                     access_key=access_key,
                                     secret_key=secret_key,
                                     dry_run=dry_run)
    elif rancher_mode == 'access_control':
        msg = "SKIP: 'access_control' Not yet implemented"

    return changed, msg


def main():
    module = AnsibleModule(
        argument_spec=dict(
            rancher=dict(type='str', required=True,
                         aliases=['server',
                                  'rancher_api',
                                  'rancher_server',
                                  'api']),
            account_key=dict(type='str', required=False),
            mode=dict(required=True,
                      choices=['settings', 'access_control'],
                      aliases=['api_mode']),
            data=dict(type='dict', required=True),
            timeout=dict(type='float', default=default_timeout),
        ),
        supports_check_mode=True
    )

    rancher_server = module.params['rancher']
    rancher_account_key = module.params['account_key']
    rancher_mode = module.params['mode']
    rancher_data = module.params['data']
    rancher_timeout = module.params['timeout']

    try:
        changed, msg = mode_handler(rancher_server,
                                    rancher_mode,
                                    data=rancher_data,
                                    account_key=rancher_account_key,
                                    timeout=rancher_timeout,
                                    dry_run=module.check_mode)
    except ModeError as e:
        module.fail_json(msg=str(e))

    module.exit_json(changed=changed, msg=msg)


if __name__ == '__main__':
    main()
