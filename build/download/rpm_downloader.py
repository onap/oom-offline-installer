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
from collections import defaultdict

from command_downloader import CommandDownloader

log = logging.getLogger(name=__name__)


class RpmDownloader(CommandDownloader):
    def __init__(self, *list_args):
        super().__init__('rpm packages', 'yumdownloader', *list_args)
        # beneficial to have it in same format

    @property
    def check_table(self):
        """
        Return check table for rpm packages
        :return: '' not implemented
        """
        log.warning('Check mode for rpms is not implemented.')
        return ''

    @staticmethod
    def _download_rpm_set(dst, rpms):
        command = 'yumdownloader --destdir={} {}'.format(dst, ' '.join(rpms))
        log.info('Running command: {}'.format(command))
        log.info(
            subprocess.check_output(command.split(), stderr=subprocess.STDOUT).decode())
        log.info('Downloaded: {}'.format(', '.join(sorted(rpms))))

    def missing(self):
        """
        Check for missing rpms (not downloaded)
        :return: dictionary of missing items grouped by dst dir
        """
        # we need slightly different format for yumdownloader
        self._missing = defaultdict(set)
        for item, dst in self._data_list.items():
            self._missing[dst].add(item)
        return self._missing

    def _is_missing(self, item): # pylint: disable=W0613
        """
        Check if item is missing
        :param item: item to check
        :return: it is always missing because not sure about downloaded filename
        """
        # don't know file names so always missing
        return True

    def _initial_log(self):
        """
        Simpler then in parent
        """
        class_name = type(self).__name__
        log.info('{}: Initializing download {} {} are not present.'.format(class_name, len(self._data_list),
                                                                           self._list_type))

    def download(self):
        """
        Download rpm packages from lists
        """
        self._initial_log()
        error_occurred = False

        for dst, rpm_set in self._missing.items():
            try:
                self._download_rpm_set(dst, rpm_set)
            except subprocess.CalledProcessError as err:
                log.exception(err.output)
                error_occurred = True
        if error_occurred:
            log.error('Download failed')
            raise RuntimeError('Download unsuccessful')


def run_cli():
    """
    Run as cli tool
    """
    parser = argparse.ArgumentParser(description='Download rpm packages from list')
    parser.add_argument('rpm_list', metavar='rpm-list',
                        help='File with list of npm packages to download.')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')

    args = parser.parse_args()

    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    timer_start = timeit.default_timer()
    try:
        downloader = RpmDownloader([args.rpm_list, args.output_dir])
        downloader.download()
    except RuntimeError:
        sys.exit(1)
    finally:
        log.info('Downloading finished in {}'.format(
            datetime.timedelta(seconds=timeit.default_timer() - timer_start)))


if __name__ == '__main__':
    run_cli()
