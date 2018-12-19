#!/usr/bin/python

from ansible.module_utils.basic import AnsibleModule
import json
import os

DOCUMENTATION="""
---
module: json_add
descritption:
  - This module will search top level objects in json and adds specified
    value into list for specified key.
  - If file does not exists module will create it automatically.

options:
  path:
    required: true
    aliases=[name, destfile, dest]
    description:
      - The json file to modify.
  key:
    required: true
    description:
      - Top level object.
  value:
    required: true
    description:
      - Value to add to specified key.
"""

def load_json(path):
    if os.path.exists(path):
        with open(path, 'r') as f:
          return json.load(f)
    else:
        return {}

def value_is_set(path, key, value, json_obj):
    return value in json_obj.get(key, [])

def insert_to_json(path, key, value, check_mode=False):
    json_obj = load_json(path)
    if not value_is_set(path, key, value, json_obj):
        if not check_mode:
            json_obj.setdefault(key, []).append(value)
            store_json(path, json_obj)
        return True, 'Value %s added to %s.' % (value, key)
    else:
        return False, ''

def store_json(path, json_obj):
    with open(path, 'w') as f:
        json.dump(json_obj, f, indent=4)

def check_file_attrs(module, changed, message, diff):
    file_args = module.load_file_common_arguments(module.params)
    if module.set_fs_attributes_if_different(file_args, False, diff=diff):

        if changed:
            message += ' '
        changed = True
        message += 'File attributes changed.'

    return changed, message

def run_module():
    module = AnsibleModule(
        argument_spec=dict(
        path=dict(type='path', required=True, aliases=['name', 'destfile', 'dest']),
        key=dict(type='str', required=True),
        value=dict(type='str', required=True),
        ),
        add_file_common_args=True,
        supports_check_mode=True
    )
    params = module.params
    path = params['path']
    key = params['key']
    value = params['value']
    try:
        changed, msg = insert_to_json(path, key, value, module.check_mode)
        fs_diff = {}
        changed, msg = check_file_attrs(module, changed, msg, fs_diff)
        module.exit_json(changed=changed, msg=msg, file_attr_diff=fs_diff)
    except IOError as e:
        module.fail_json(msg=e.msg)

if __name__ == '__main__':
    run_module()

