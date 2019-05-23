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

import argparse
import logging
import sys
import os

import base
import docker_images
import git_repos
import http_files
import npm_packages
import rpm_packages

def run_cli():
    parser=argparse.ArgumentParser(description='Download data from lists')
    parser.add_argument('--docker', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'), help='Docker image type list')
    parser.add_argument('--docker-save', action='store_true', default=False,
                         help='Save Docker images')
    parser.add_argument('--http', action='append', nargs=2, default=[], metavar=('list', 'dir-name'),
                        help='Http type list')
    parser.add_argument('--npm', action='append', nargs=2, default=[], metavar=('list', 'dir-name'),
                        help='Npm type list')
    parser.add_argument('--npm-registry', '-r', default='https://registry.npmjs.org',
                        help='npm registry to use')
    parser.add_argument('--rpm', action='append', nargs=2, default=[], metavar=('list', 'dir-name'),
                        help='Rpm type list')
    parser.add_argument('--git', action='append', nargs=2, default=[], metavar=('list', 'dir-name'),
                        help='Git repo type list')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check what is missing. No download.')

    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)
    for docker_list in args.docker:
        docker_images.download(docker_list[0], args.docker_save,
                               '{}/{}'.format(args.output_dir, docker_list[1]),
                               args.check, base.init_progress('docker images'))

    for http_list in args.http:
        http_files.download(http_list[0], '{}/{}'.format(args.output_dir, http_list[1]),
                            args.check, base.init_progress('http files'))

    for npm_list in args.npm:
        npm_packages.download(npm_list[0], args.npm_registry,
                            '{}/{}'.format(args.output_dir, npm_list[1]),
                            args.check, base.init_progress('npm packages'))

    for rpm_list in args.rpm:
        if args.check:
            log.info('Check mode is not implemented')
            break
        rpm_packages.download(rpm_list[0], '{}/{}'.format(args.output_dir, rpm_list[1]))

    for git_list in args.git:
        if args.check:
            log.info('Check mode is not implemented')
            break
        git_repos.download(git_list[0], '{}/{}'.format(args.output_dir, git_list[1]),
                           base.init_progress('git repositories'))


if __name__ == '__main__':
    run_cli()

