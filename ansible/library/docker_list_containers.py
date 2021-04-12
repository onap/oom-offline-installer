#!/usr/bin/python

ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community'
}

DOCUMENTATION = '''
---
module: docker_list_containers

short_description: "List running docker containers"

description:
    - "Lists all running containers or those with matching label"

options:
    label_name:
        description:
            - container label name to match
        required: false
    label_value:
        description:
            - container label value to match
        required: false

author:
    - Bartek Grzybowski (b.grzybowski@partner.samsung.com)
'''

EXAMPLES = '''
# List all running containers
- name: List containers
  docker_list_containers:

# List all running containers matching label
- name: List containers
  docker_list_containers:
    label_name: 'io.rancher.project.name'
    label_value: 'kubernetes'
'''

RETURN = '''
containers:
    description: List of running containers matching module criteria
    type: list
    returned: always
    sample: [
        "rancher-agent",
        "rancher-server",
        "kubernetes-node-1",
        "infrastructure-server"
    ]
'''

from ansible_collections.community.docker.plugins.module_utils.common import AnsibleDockerClient

class DockerListContainers:

    def __init__(self):
        self.docker_client = AnsibleDockerClient(
            argument_spec=dict(
                label_name=dict(type='str', required=False),
                label_value=dict(type='str', required=False)
            )
        )

        self.containers = self.docker_client.containers()
        self.label_name=self.docker_client.module.params.get('label_name')
        self.label_value=self.docker_client.module.params.get('label_value')

        if self.label_name:
            self.containers_names=self._get_containers_names_by_label()
        else:
            self.containers_names=self._get_containers_names()

        self.result=dict(
            containers=self.containers_names,
            changed=False
        )

    def _get_containers_names(self):
        return [str(container_meta.get('Names')[0][1:]) for container_meta in self.containers if 'Names' in container_meta]

    def _get_containers_names_by_label(self):
        names=[]
        for container_meta in self.containers:
            if container_meta.get('Labels',{}).get(self.label_name) == self.label_value:
                names.append(str(container_meta['Names'][0][1:])) # strip leading '/' in container name and convert to str from unicode

        return names

def main():
    cont=DockerListContainers()
    cont.docker_client.module.exit_json(**cont.result)

if __name__ == '__main__':
    main()
