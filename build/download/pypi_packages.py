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
import subprocess
import os
from retrying import retry

import base

log = logging.getLogger(name=__name__)

@retry(stop_max_attempt_number=5, wait_fixed=5000)
def download_package(package_name, dst_dir):
    command = 'pip download --dest {} {}'.format(dst_dir, package_name)
    log.info('Running: {}'.format(command))
    log.info(subprocess.check_output(command.split(), stderr=subprocess.STDOUT).decode())
    log.info('Downloaded: {}'.format(package_name))


def download(pypi_list, dst_dir, progress):
    if not base.check_tool('pip'):
        log.error('ERROR: pip is not installed')
        progress.finish(dirty=True)
        raise RuntimeError('pip missing')

    pypi_set = base.load_list(pypi_list)

    error_count = 0

    base.start_progress(progress, len(pypi_set), [], log)

    for package in pypi_set:
        try:
            download_package(package, dst_dir)
        except subprocess.CalledProcessError as err:
            log.exception(err.output.decode())
            error_count += 1

        progress.update(progress.value + 1)

    base.finish_progress(progress, error_count, log)
    if error_count > 0:
        log.error('{} packages were not downloaded. Check logs for details'.format(error_count))
        raise RuntimeError('Download unsuccesfull')


def run_cli():
    parser = argparse.ArgumentParser(description='Download git repositories from list')
    parser.add_argument('pypi_list', metavar='pypi-list',
                        help='File with list of pypi packages to download.')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')

    args = parser.parse_args()

    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    progress = base.init_progress('pypi packages')
    try:
        download(args.pypi_list, args.output_dir, progress)
    except RuntimeError as err:
        log.exception(err)
        sys.exit(1)


if __name__ == '__main__':
    run_cli()
