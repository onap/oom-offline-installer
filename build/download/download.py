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
import datetime
import timeit

import base
import docker_images
import git_repos
import http_files
import npm_packages
import pypi_packages
import rpm_packages

log = logging.getLogger(name=__name__)

def parse_args():
    parser=argparse.ArgumentParser(description='Download data from lists')
    list_group = parser.add_argument_group()
    list_group.add_argument('--docker', action='append', nargs='+', default=[],
                        metavar=('list', 'dir-name'),
                        help='Docker type list. If second argument is specified '
                             'it is treated as directory where images will be saved '
                             'otherwise only pull operation is executed')
    list_group.add_argument('--http', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'),
                        help='Http type list and directory to save downloaded files')
    list_group.add_argument('--npm', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'),
                        help='npm type list and directory to save downloaded files')
    list_group.add_argument('--rpm', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'),
                        help='rpm type list and directory to save downloaded files')
    list_group.add_argument('--git', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'),
                        help='git repo type list and directory to save downloaded files')
    list_group.add_argument('--pypi', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'),
                        help='pypi packages type list and directory to save downloaded files')
    parser.add_argument('--npm-registry', default='https://registry.npmjs.org',
                        help='npm registry to use (default: https://registry.npmjs.org)')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check what is missing. No download.')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')

    args = parser.parse_args()

    for arg in ('docker', 'npm', 'http', 'rpm', 'git', 'pypi'):
        if getattr(args, arg):
            return args

    parser.error('One of --docker, --npm, --http, --rpm, --git must be specified')


def run_cli():
    args = parse_args()

    console_handler = logging.StreamHandler(sys.stdout)
    console_formatter = logging.Formatter('%(message)s')
    console_handler.setFormatter(console_formatter)
    now = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    log_file = 'download_data-{}.log'.format(now)
    file_format = "%(asctime)s: %(filename)s: %(levelname)s: %(message)s"

    if args.debug:
        logging.basicConfig(level=logging.DEBUG, filename=log_file, format=file_format)
    else:
        logging.basicConfig(level=logging.INFO, filename=log_file, format=file_format)
    root_logger = logging.getLogger()
    root_logger.addHandler(console_handler)

    list_with_errors = []
    timer_start = timeit.default_timer()

    for docker_list in args.docker:
        log.info('Processing {}.'.format(docker_list[0]))
        progress = None if args.check else base.init_progress('docker images')
        save = False
        if len(docker_list) > 1:
            save = True
        else:
            docker_list.append(None)
        try:
            docker_images.download(docker_list[0], save,
                                   docker_list[1], args.check, progress)
        except RuntimeError:
            list_with_errors.append(docker_list[0])

    for http_list in args.http:
        progress = None if args.check else base.init_progress('http files')
        log.info('Processing {}.'.format(http_list[0]))
        try:
            http_files.download(http_list[0], http_list[1], args.check,
                                progress)
        except RuntimeError:
            list_with_errors.append(http_list[0])

    for npm_list in args.npm:
        progress = None if args.check else base.init_progress('npm packages')
        log.info('Processing {}.'.format(npm_list[0]))
        try:
            npm_packages.download(npm_list[0], args.npm_registry, npm_list[1],
                                  args.check, progress)
        except RuntimeError:
            list_with_errors.append(npm_list[0])

    for rpm_list in args.rpm:
        if args.check:
            log.info('Check mode for rpm packages is not implemented')
            break
        log.info('Processing {}.'.format(rpm_list[0]))
        try:
            rpm_packages.download(rpm_list[0], rpm_list[1])
        except RuntimeError:
            list_with_errors.append(rpm_list[0])

    for git_list in args.git:
        if args.check:
            log.info('Check mode for git repositories is not implemented')
            break
        progress = None if args.check else base.init_progress('git repositories')
        log.info('Processing {}.'.format(git_list[0]))
        try:
            git_repos.download(git_list[0], git_list[1], progress)
        except RuntimeError:
            list_with_errors.append(git_list[0])

    for pypi_list in args.pypi:
        if args.check:
            log.info('Check mode for pypi packages is not implemented')
            break
        progress = None if args.check else base.init_progress('pypi packages')
        log.info('Processing {}.'.format(pypi_list[0]))
        try:
            pypi_packages.download(pypi_list[0], pypi_list[1], progress)
        except RuntimeError:
            list_with_errors.append(pypi_list[0])

    e_time = datetime.timedelta(seconds=timeit.default_timer() - timer_start)
    log.info(timeit.default_timer() - timer_start)
    log.info('Execution ended. Total elapsed time {}'.format(e_time))

    if list_with_errors:
        log.error('Errors encountered while processing these lists:'
                  '\n{}'.format('\n'.join(list_with_errors)))
        sys.exit(1)



if __name__ == '__main__':
    run_cli()
