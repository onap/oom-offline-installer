#!/usr/bin/python
ANSIBLE_METADATA = {
    'METADATA_VERSION': '1.1',
    'supported_by': 'community',
    'status': 'preview'
}

DOCUMENTATION = '''
---
module: "os_floating_ips_facts"
short_description: "Retrieves facts about floating ips"
description:
  - "This module retrieves facts about one or more floating ips allocated to project."
version_added: "2.7"
author:
  - "Michal Zegan"
requirements:
  - "python => 2.7"
  - "openstacksdk"
options:
  floating_ip:
    description:
      - "The floating ip to retrieve facts for"
    type: "str"
  network:
    description:
      - "Name or id of the floating ip network to query."
    required: true
    type: "str"
notes:
  - "Registers facts starting with openstack_floating_ips"
extends_documentation_fragment: openstack
'''

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.openstack import openstack_full_argument_spec, openstack_module_kwargs, openstack_cloud_from_module

def run_module():
    args=openstack_module_kwargs()
    argspec=openstack_full_argument_spec(
      floating_ip=dict(type=str),
      network=dict(type=str, required=True))
    module=AnsibleModule(argument_spec=argspec, **args)
    sdk, cloud = openstack_cloud_from_module(module)
    try:
        fip_network=cloud.network.find_network(module.params['network'])
        filter=dict(
          project_id=cloud.current_project_id,
          floating_network_id=fip_network.id)
        if not (module.params['floating_ip'] is None):
            filter['floating_ip_address'] = module.params['floating_ip']
        ips=[dict(x) for x in cloud.network.ips(**filter)]
        module.exit_json(
          changed=False,
          ansible_facts=dict(openstack_floating_ips=ips)
        )
    except sdk.exceptions.OpenStackCloudException as e:
        module.fail_json(msg=str(e))

if __name__ == '__main__':
    run_module()
