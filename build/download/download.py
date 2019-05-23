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
import rpm_packages

log = logging.getLogger(name=__name__)

def run_cli():
    parser=argparse.ArgumentParser(description='Download data from lists')
    parser.add_argument('--docker', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'), help='Docker image type list')
    parser.add_argument('--docker-save', action='store_true', default=False,
                         help='Save Docker images')
    parser.add_argument('--http', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'), help='Http type list')
    parser.add_argument('--npm', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'), help='Npm type list')
    parser.add_argument('--npm-registry', default='https://registry.npmjs.org',
                        help='npm registry to use')
    parser.add_argument('--rpm', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'), help='Rpm type list')
    parser.add_argument('--git', action='append', nargs=2, default=[],
                        metavar=('list', 'dir-name'), help='Git repo type list')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check what is missing. No download.')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')

    args = parser.parse_args()

    console_handler = logging.StreamHandler(sys.stdout)
    console_formatter = logging.Formatter('%(message)s')
    console_handler.setFormatter(console_formatter)
    now = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    log_file = 'download_data-{}.log'.format(now)
    file_handler = logging.FileHandler(log_file)
    file_formatter = logging.Formatter("%(asctime)s: %(filename)s: %(levelname)s: %(message)s")
    file_handler.setFormatter(file_formatter)
    handlers = [console_handler, file_handler]

    if args.debug:
        logging.basicConfig(level=logging.DEBUG, handlers=handlers)
    else:
        logging.basicConfig(level=logging.INFO, handlers=handlers)

    error_count = 0
    timer_start = timeit.default_timer()

    for docker_list in args.docker:
        log.info('Processing {}.'.format(docker_list[0]))
        progress = None if args.check else base.init_progress('docker images')
        error_count += docker_images.download(docker_list[0], args.docker_save,
                       docker_list[1], args.check, progress)

    for http_list in args.http:
        progress = None if args.check else base.init_progress('http files')
        log.info('Processing {}.'.format(http_list[0]))
        error_count += http_files.download(http_list[0], http_list[1], args.check,
                                           progress)

    for npm_list in args.npm:
        progress = None if args.check else base.init_progress('npm packages')
        log.info('Processing {}.'.format(npm_list[0]))
        error_count += npm_packages.download(npm_list[0], args.npm_registry, npm_list[1],
                                             args.check, progress)

    for rpm_list in args.rpm:
        if args.check:
            log.info('Check mode for rpm packages is not implemented')
            break
        log.info('Processing {}.'.format(rpm_list[0]))
        error_count += rpm_packages.download(rpm_list[0], rpm_list[1])

    for git_list in args.git:
        if args.check:
            log.info('Check mode for git repositories is not implemented')
            break
        progress = None if args.check else base.init_progress('git repositories')
        log.info('Processing {}.'.format(git_list[0]))
        error_count += git_repos.download(git_list[0], git_list[1], progress)

    if error_count > 0:
        log.error('Some errors encountered. Check logs for details')

    e_time = datetime.timedelta(seconds=timeit.default_timer() - timer_start)
    log.info(timeit.default_timer() - timer_start)
    log.info('Execution ended. Total elapsed time {}'.format(e_time))
    return error_count


if __name__ == '__main__':
    run_cli()
