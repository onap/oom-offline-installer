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
import datetime
import logging
import os
import shutil
import subprocess
import sys
import timeit

import command_downloader

log = logging.getLogger(name=__name__)


class GitDownloader(command_downloader.CommandDownloader):
    def __init__(self, *list_args):
        super().__init__('git repositories', 'git', *list_args)

    @property
    def check_table(self):
        """
        Table with information which items from lists are downloaded
        """
        self.missing()
        header = ['Name', 'Branch', 'Downloaded']
        return self._check_table(header, {'Name': 'l'},
                                 ((*item.split(), self._downloaded(item)) for item
                                  in self._data_list))

    @staticmethod
    def _download_item(item):
        repo, branch = item[0].split()
        dst = '{}/{}'.format(item[1], repo)
        command = 'git clone -b {} --single-branch https://{} --bare {}'.format(branch,
                                                                                repo,
                                                                                dst)
        if os.path.exists(dst):
            log.warning('File or directory exists {} removing and cloning'
                        ' to be sure it is latest.'.format(dst))
            if os.path.isfile(dst):
                os.remove(dst)
            elif os.path.isdir(dst):
                shutil.rmtree(dst)

        log.info('Running: {}'.format(command))
        log.info(
            subprocess.check_output(command.split(), stderr=subprocess.STDOUT).decode())
        log.info('Downloaded: {}'.format(repo))

    def _is_missing(self, item):
        """
        Check if item is missing (not cloned)
        :param item: item to check
        :return: True if not present 'maybe' if directory exists
        """
        dst = '{}/{}'.format(self._data_list[item], item.split()[0])
        if os.path.exists(dst):
            # it is bare repo who knows
            return 'maybe'
        return True

    def _downloaded(self, item):
        """
        Check if item is present (cloned)
        :param item: item to check
        :return: True if not cloned 'maybe' if directory exists
        """
        missing = self._is_missing(item)
        if missing != 'maybe':
            return False
        # It is bare repo so who knows if it is latest version
        return 'maybe'

    def missing(self):
        """
        Check for missing data (not downloaded)
        :return: dictionary of missing items
        """
        self._missing = {item: dst for item, dst in self._data_list.items()}
        return self._missing


def run_cli():
    """
    Run as cli tool
    """
    parser = argparse.ArgumentParser(description='Download git repositories from list')
    parser.add_argument('git_list', metavar='git-list',
                        help='File with list of npm packages to download.')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check mode')

    args = parser.parse_args()

    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    downloader = GitDownloader([args.git_list, args.output_dir])
    if args.check:
        log.info('Check mode. No download will be executed.')
        log.info(downloader.check_table)
        sys.exit(0)

    timer_start = timeit.default_timer()
    try:
        downloader.download()
    except RuntimeError:
        sys.exit(1)
    finally:
        log.info('Downloading finished in {}'.format(
            datetime.timedelta(seconds=timeit.default_timer() - timer_start)))


if __name__ == '__main__':
    run_cli()
