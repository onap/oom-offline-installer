#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule

import os
import copy
import json

try:
    import jsonpointer
except ImportError:
    jsonpointer = None

DOCUMENTATION = """
---
module: json_mod
short_description: Modifies json data inside a file
description:
  - This module modifies a file containing a json.
  - It is leveraging jsonpointer module implementing RFC6901:
    https://pypi.org/project/jsonpointer/
    https://tools.ietf.org/html/rfc6901
  - If the file does not exist the module will create it automatically.

options:
  path:
    description:
      - The json file to modify.
    required: true
    aliases:
      - name
      - destfile
      - dest
  key:
    description:
      - Pointer to the key inside the json object.
      - You can leave out the leading slash '/'.
      - The last object in the pointer can be missing but the intermediary
        objects must exist.
    required: true
  value:
    description:
      - Value to be added/changed for the key specified by pointer.
    required: true
  action:
    description:
      - It ensures that key/value exists - 'add', or it will either 'append'
        value to the existent value or it will 'replace' the original value
        with the new one in 'value'.
      - 'add' simply adds value if it not exists or does nothing.
      - 'append' works only on dicts (both key and new value) and lists (key).
        If key is a dict. and value is a dict. then 'append' will add new
        pairs from value to the key - it will not overwrite any old values.
      - 'update' works only on dicts (both key and new value). It behaves
        similarly to 'append' but it WILL overwrite old values.
      - 'extend' adds items from value, which must be a list, to the key which
        also must be a list.
      - 'replace' simply replaces any old or creates a new value for the key.
    required: false
    default: add
    choices:
      - add
      - append
      - update
      - extend
      - replace
"""


def load_json(path):
    if os.path.exists(path):
        with open(path, 'r') as f:
            return json.load(f)
    else:
        return {}


def store_json(path, json_data):
    with open(path, 'w') as f:
        json.dump(json_data, f, indent=4)
        f.write("\n")


def modify_json(json_data, pointer, value, action='add'):
    is_root = False
    key_exists = False
    changed = False

    # keep original intact and avoid reference loop
    value = copy.deepcopy(value)

    if action not in ['add', 'append', 'update', 'extend', 'replace']:
        raise ValueError

    try:
        target = jsonpointer.resolve_pointer(json_data, pointer)
        if pointer == '':
            is_root = True
        else:
            key_exists = True
    except jsonpointer.JsonPointerException:
        key_exists = False

    if is_root:
        target = jsonpointer.set_pointer(json_data,
                                         pointer,
                                         value,
                                         inplace=False)
        json_data = target
        changed = True
    elif key_exists:
        if action == "append":
            if isinstance(target, dict) and isinstance(value, dict):
                # we keep old values and only append new ones
                value.update(target)
                target = jsonpointer.set_pointer(json_data, pointer, value)
            elif isinstance(target, list):
                target.append(value)
            else:
                raise ValueError
            changed = True
        elif action == "update":
            if isinstance(target, dict) and isinstance(value, dict):
                target.update(value)
            else:
                raise ValueError
            changed = True
        elif action == "extend":
            if isinstance(target, list) and isinstance(value, list):
                target.extend(value)
            else:
                raise ValueError
        elif action == "replace":
            target = jsonpointer.set_pointer(json_data, pointer, value)
            changed = True
    else:
        target = jsonpointer.set_pointer(json_data, pointer, value)
        changed = True

    if changed:
        msg = "JSON object '%s' was updated" % pointer
    else:
        msg = "No change to JSON object '%s'" % pointer

    return json_data, changed, msg


def main():
    module = AnsibleModule(
        argument_spec=dict(
            path=dict(type='path', required=True,
                      aliases=['name', 'destfile', 'dest']),
            key=dict(type='str', required=True),
            value=dict(type='str', required=True),
            action=dict(required=False, default='add',
                        choices=['add',
                                 'append',
                                 'update',
                                 'extend',
                                 'replace']),
        ),
        supports_check_mode=True
    )

    if jsonpointer is None:
        module.fail_json(msg='jsonpointer module is not available')

    path = module.params['path']
    pointer = module.params['key']
    value = module.params['value']
    action = module.params['action']

    if pointer == '' or pointer == '/':
        pass
    elif not pointer.startswith("/"):
        pointer = "/" + pointer

    try:
        json_data = load_json(path)
        value = json.loads(value)
    except Exception as err:
        module.fail_json(msg=str(err))

    try:
        json_data, changed, msg = modify_json(json_data,
                                              pointer,
                                              value,
                                              action)
    except jsonpointer.JsonPointerException as err:
        module.fail_json(msg=str(err))
    except ValueError as err:
        module.fail_json(msg="Wrong usage of action and/or key/value")

    try:
        if not module.check_mode:
            store_json(path, json_data)
    except IOError as err:
        module.fail_json(msg=str(err))

    module.exit_json(changed=changed, msg=msg)


if __name__ == '__main__':
    main()
