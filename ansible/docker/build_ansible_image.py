#! /usr/bin/env python
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

from datetime import datetime
from shutil import rmtree
import argparse
import logging
import tarfile
import sys
import io
import os

import docker
import git

log = logging.getLogger(__name__)
script_path = os.path.realpath(__file__)
script_location = os.path.dirname(script_path)


def build_ansible_chroot(path, output, ansible_version='2.7.8', overwrite=False):
    """
    :param path: Path to directory with Dockerfile
    :param output: Path to output directory
    :param ansible_version: Version of ansible to be included into chroot
    :param overwrite: overwrite previously created output file
    :return:
    """

    if os.path.exists(os.path.join(output, 'ansible_chroot.tgz')) and not overwrite:
        log.error('Output directory is not empty, use overwrite to force build')
        raise FileExistsError

    git_commit = git.Repo(os.path.join(script_location, '..', '..')).head.commit.hexsha
    build_args = {'ansible_version': ansible_version}
    labels = {'build-date': datetime.now().strftime('%Y-%m-%d_%H-%M'),
              'ansible_version': ansible_version,
              'git-commit': git_commit
              }

    try:
        docker_client = docker.client.DockerClient(version='auto', timeout=300)
    except docker.errors.DockerException as err:
        log.exception('Error creating docker client. Check if is docker installed and running'
                      ' or if you have right permissions.')
        raise err

    offline_installer_image = docker_client.images.build(path=path,
                                                         buildargs=build_args,
                                                         labels=labels)[0]
    offline_installer_container = docker_client.containers.create(offline_installer_image)

    exported_tar_bytes = b''.join(offline_installer_container.export())
    exported_tar = io.BytesIO(exported_tar_bytes)
    temp_chroot = os.path.join(output, 'chroot')
    with tarfile.open(fileobj=exported_tar) as tar:
        tar.extractall(temp_chroot)
    with tarfile.open(os.path.join(output, 'ansible_chroot.tgz'), 'w:gz') as out_put_targz:
        out_put_targz.add(temp_chroot, '')

    rmtree(temp_chroot)
    offline_installer_container.remove()


def run_cli():
    """
    Run as cli tool
    """
    parser = argparse.ArgumentParser(description='Builds docker container and exports it to tar.gz')
    parser.add_argument('--path', '-p', default=script_location,
                        help='Path to directory with Dockerfile')
    parser.add_argument('--output', '-o', default=os.path.join(script_location),
                        help='Full path to output directory')
    parser.add_argument('--ansible-version', default='2.7.8', help='Version of ansible to be included into chroot')
    parser.add_argument('--overwrite', action='store_true', default=False,
                        help='overwrite previously created output file')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')
    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    else:
        logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    log.info('Building image and creating chroot directory with ansible version {}'.format(args.ansible_version))

    build_ansible_chroot(args.path,
                         args.output,
                         args.ansible_version,
                         args.overwrite)


if __name__ == '__main__':
    run_cli()
