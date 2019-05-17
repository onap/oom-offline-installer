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
import subprocess
import logging
import sys
import os

import base

log = logging.getLogger(name=__name__)


def download(rpm_list, dst_dir):
    if not base.check_tool('yumdownloader'):
        log.error('ERROR: yumdownloader is not installed')
        return 1

    rpm_set = base.load_list(rpm_list)

    command = 'yumdownloader --destdir={} {}'.format(dst_dir, ' '.join(rpm_set))
    log.info('Running command: {}'.format(command))
    try:
        subprocess.check_call(command.split())
        log.info('Downloaded')
    except subprocess.CalledProcessError as err:
        log.error(err.output)
        return err.returncode



def run_cli():
    parser = argparse.ArgumentParser(description='Download rpm packages from list')
    parser.add_argument('rpm_list', metavar='rpm-list',
                        help='File with list of npm packages to download.')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')

    args = parser.parse_args()

    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    sys.exit(download(args.rpm_list, args.output_dir))


if __name__ == '__main__':
    run_cli()
