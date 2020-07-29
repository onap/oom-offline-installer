#! /usr/bin/env python3
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
import datetime
import logging
import os
import subprocess
import sys
import timeit

from retrying import retry

from command_downloader import CommandDownloader

log = logging.getLogger(name=__name__)


class PyPiDownloader(CommandDownloader):
    def __init__(self, *list_args):
        super().__init__('pypi packages', 'pip', *list_args)

    @property
    def check_table(self):
        """
        Return check table for pypi packages
        :return: '' not implemented
        """
        log.warning('Check mode for pypi is not implemented.')
        return ''

    def _is_missing(self, item): # pylint: disable=W0613
        """
        Check if item is missing
        :param item: item to check
        :return: True since don't know the actual filename
        """
        # always true don't know the name
        return True

    @retry(stop_max_attempt_number=5, wait_fixed=5000)
    def _download_item(self, item):
        """
        Download pip package using pip
        :param item: tuple(package_name, dst_dir) (name possibly with version specification)
        """
        package_name, dst_dir = item
        command = 'pip download --dest {} {}'.format(dst_dir, package_name)
        log.info('Running: {}'.format(command))
        log.info(
            subprocess.check_output(command.split(), stderr=subprocess.STDOUT).decode())
        log.info('Downloaded: {}'.format(package_name))


def run_cli():
    """
    Run as cli tool
    """
    parser = argparse.ArgumentParser(description='Download git repositories from list')
    parser.add_argument('pypi_list', metavar='pypi-list',
                        help='File with list of pypi packages to download.')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')

    args = parser.parse_args()

    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    downloader = PyPiDownloader([args.pypi_list, args.output_dir])

    timer_start = timeit.default_timer()
    try:
        downloader.download()
    except RuntimeError as err:
        log.exception(err)
        sys.exit(1)
    finally:
        log.info('Downloading finished in {}'.format(
            datetime.timedelta(seconds=timeit.default_timer() - timer_start)))


if __name__ == '__main__':
    run_cli()
