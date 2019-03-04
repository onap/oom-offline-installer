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
      - You can leave out the leading slash '/'. It will be prefixed by the
        module for convenience ('key' equals '/key').
      - Empty key '' designates the whole JSON document (RFC6901)
      - Key '/' is valid too and it translates to '' ("": "some value").
      - The last object in the pointer can be missing but the intermediary
        objects must exist.
    required: true
  value:
    description:
      - Value to be added/changed for the key specified by pointer.
      - In the case of 'state = absent' the module will delete those elements
        described in the value. If the whole key/value should be deleted then
        value must be set to the empty string '' !
    required: true
  state:
    description:
      - It states either that the combination of key and value should be
        present or absent.
      - If 'present' then the exact results depends on 'action' argument.
      - If 'absent' and key does not exists - no change, if does exist but
        'value' is unapplicable (old value is dict, but new is not), then the
        module will raise error. Special 'value' for state 'absent' is an empty
        string '' (read above). If 'value' is applicable (both key and value is
        dict or list) then it will remove only those explicitly named elements.
        Please beware that if you want to remove key/value pairs from dict then
        you must provide as 'value' a valid dict - that means key/value pair(s)
        in curls {}. Here you can use just some dummy value like "". The values
        can differ, the key/value pair will be deleted if key matches.
        For example to delete key "xyz" from json object, you must provide
        'value' similar to this: { "key": ""}
    required: false
    default: present
    choices:
      - present
      - absent
  action:
    description:
      - It modifies a presence of the key/value pair when state is 'present'
        otherwise is ignored.
      - 'add' is default and means that combination of key/value will be added
        if not already there. If there is already an old value then it is
        expected that the old value and the new value are of the same type.
        Otherwise the module will fail. By the same type we mean that both of
        them are either scalars (strings, numbers), lists or dicts.
      - In the case of scalar values everything is simple - if there is already
        a value, nothing happens.
      - In the case of lists the module ensures that all components of the new
        value list are present in the result - it will extend an old value list
        with the elements of the new value list.
      - In the case of dicts the missing key/value pairs are added but those
        already present are preserved - it will NOT overwrite old values.
      - 'Update' is identical to 'add', but it WILL overwrite old values. For
        list values this has no meaning, so it behaves like add - it simply
        merges two lists (extends the old with new).
      - 'replace' will (re)create key/value combination from scratch - it means
        that the old value is completely discarded if there is any.
    required: false
    default: add
    choices:
      - add
      - update
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


def modify_json(json_data, pointer, json_value, state='present', action='add'):
    is_root = False  # special treatment - we cannot modify reference in place
    key_exists = False

    try:
        value = json.loads(json_value)
    except Exception:
        value = None

    if state == 'present':
        if action not in ['add', 'update', 'replace']:
            raise ValueError
    elif state == 'absent':
        pass
    else:
        raise ValueError

    # we store the original json document to compare it later
    original_json_data = copy.deepcopy(json_data)

    try:
        target = jsonpointer.resolve_pointer(json_data, pointer)
        if pointer == '':
            is_root = True
        key_exists = True
    except jsonpointer.JsonPointerException:
        key_exists = False

    if key_exists:
        if state == "present":
            if action == "add":
                if isinstance(target, dict) and isinstance(value, dict):
                    # we keep old values and only append new ones
                    value.update(target)
                    result = jsonpointer.set_pointer(json_data,
                                                     pointer,
                                                     value,
                                                     inplace=(not is_root))
                    if is_root:
                        json_data = result
                elif isinstance(target, list) and isinstance(value, list):
                    # we just append new items to the list
                    for item in value:
                        if item not in target:
                            target.append(item)
                elif ((not isinstance(target, dict)) and
                      (not isinstance(target, list))):
                    # 'add' does not overwrite
                    pass
                else:
                    raise ValueError
            elif action == "update":
                if isinstance(target, dict) and isinstance(value, dict):
                    # we append new values and overwrite the old ones
                    target.update(value)
                elif isinstance(target, list) and isinstance(value, list):
                    # we just append new items to the list - same as with 'add'
                    for item in value:
                        if item not in target:
                            target.append(item)
                elif ((not isinstance(target, dict)) and
                      (not isinstance(target, list))):
                    # 'update' DOES overwrite
                    if value is not None:
                        result = jsonpointer.set_pointer(json_data,
                                                         pointer,
                                                         value)
                    elif target != json_value:
                        result = jsonpointer.set_pointer(json_data,
                                                         pointer,
                                                         json_value)
                    else:
                        raise ValueError
                else:
                    raise ValueError
            elif action == "replace":
                # simple case when we don't care what was there before (almost)
                if value is not None:
                    result = jsonpointer.set_pointer(json_data,
                                                     pointer,
                                                     value,
                                                     inplace=(not is_root))
                else:
                    result = jsonpointer.set_pointer(json_data,
                                                     pointer,
                                                     json_value,
                                                     inplace=(not is_root))
                if is_root:
                    json_data = result
            else:
                raise ValueError
        elif state == "absent":
            # we will delete the elements in the object or object itself
            if is_root:
                if json_value == '':
                    # we just return empty json
                    json_data = {}
                elif isinstance(target, dict) and isinstance(value, dict):
                    for key in value:
                        target.pop(key, None)
                else:
                    raise ValueError
            else:
                # we must take a step back in the pointer, so we can edit it
                ppointer = pointer.split('/')
                to_delete = ppointer.pop()
                ppointer = '/'.join(ppointer)
                ptarget = jsonpointer.resolve_pointer(json_data, ppointer)
                if (((not isinstance(target, dict)) and
                        (not isinstance(target, list)) and
                        json_value == '') or
                        (isinstance(target, dict) or
                         isinstance(target, list)) and
                        json_value == ''):
                    # we simply delete the key with it's value (whatever it is)
                    ptarget.pop(to_delete, None)
                    target = ptarget  # piece of self-defense
                elif isinstance(target, dict) and isinstance(value, dict):
                    for key in value:
                        target.pop(key, None)
                elif isinstance(target, list) and isinstance(value, list):
                    for item in value:
                        try:
                            target.remove(item)
                        except ValueError:
                            pass
                else:
                    raise ValueError
        else:
            raise ValueError
    else:
        # the simplest case - nothing was there before and pointer is not root
        # because in that case we would have key_exists = true
        if state == 'present':
            if value is not None:
                result = jsonpointer.set_pointer(json_data,
                                                 pointer,
                                                 value)
            else:
                result = jsonpointer.set_pointer(json_data,
                                                 pointer,
                                                 json_value)

    if json_data != original_json_data:
        changed = True
    else:
        changed = False

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
            state=dict(default='present', choices=['present', 'absent']),
            action=dict(required=False, default='add',
                        choices=['add',
                                 'update',
                                 'replace']),
        ),
        supports_check_mode=True
    )

    if jsonpointer is None:
        module.fail_json(msg='jsonpointer module is not available')

    path = module.params['path']
    pointer = module.params['key']
    value = module.params['value']
    state = module.params['state']
    action = module.params['action']

    if pointer == '' or pointer == '/':
        pass
    elif not pointer.startswith("/"):
        pointer = "/" + pointer

    try:
        json_data = load_json(path)
    except Exception as err:
        module.fail_json(msg=str(err))

    try:
        json_data, changed, msg = modify_json(json_data,
                                              pointer,
                                              value,
                                              state,
                                              action)
    except jsonpointer.JsonPointerException as err:
        module.fail_json(msg=str(err))
    except ValueError as err:
        module.fail_json(msg="Wrong usage of state, action and/or key/value")

    try:
        if not module.check_mode and changed:
            store_json(path, json_data)
    except IOError as err:
        module.fail_json(msg=str(err))

    module.exit_json(changed=changed, msg=msg)


if __name__ == '__main__':
    main()
