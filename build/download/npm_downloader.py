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
import hashlib
import logging
import os
import sys
import timeit

from retrying import retry

import http_downloader
import http_file

log = logging.getLogger(__name__)


class NpmDownloader(http_downloader.HttpDownloader):
    def __init__(self, npm_registry, *list_args, workers=None):
        super().__init__(*list_args, list_type='npm packages', workers=workers)
        self._registry = npm_registry

    def _download_item(self, item):
        """
        Download npm package
        :param item: http file to be downloaded (tuple: (npm_name@version, dst_dir))
        """
        log.info('Downloading: {}'.format(item[0]))
        npm_name, npm_version = item[0].split('@')
        dst_path = '{}/{}-{}.tgz'.format(item[1], npm_name, npm_version)
        try:
            tarball = http_file.HttpFile(item[0], self._get_npm(*item[0].split('@')), dst_path)
            tarball.save_to_file()
        except Exception as err:
            log.exception('Failed: {}'.format(item[0]))
            if os.path.isfile(dst_path):
                os.remove(dst_path)
            raise err
        log.info('Downloaded: {}'.format(item[0]))

    @retry(stop_max_attempt_number=5, wait_fixed=5000)
    def _get_npm(self, npm_name, npm_version):
        """
        Download and save npm tarball to disk
        :param npm_name: name of npm package
        :param npm_version: version of npm package
        """
        npm_url = '{}/{}/{}'.format(self._registry, npm_name, npm_version)
        npm_req = self._make_get_request(npm_url)
        npm_json = npm_req.json()
        tarball_url = npm_json['dist']['tarball']
        shasum = npm_json['dist']['shasum']
        tarball_req = self._make_get_request(tarball_url)
        tarball = tarball_req.content
        if hashlib.sha1(tarball).hexdigest() == shasum:
            return tarball
        else:
            raise Exception(
                '{}@{}: Wrong checksum. Retrying...'.format(npm_name, npm_version))

    def _is_missing(self, item):
        """
        Check if item is missing (not downloaded)
        :param item: item to check
        :return: boolean
        """
        return not os.path.isfile('{}/{}-{}.tgz'.format(self._data_list[item], *item.split('@')))


def run_cli():
    """
    Run as cli tool
    """
    parser = argparse.ArgumentParser(description='Download npm packages from list')
    parser.add_argument('npm_list', metavar='npm-list',
                        help='File with list of npm packages to download.')
    parser.add_argument('--registry', '-r', default='https://registry.npmjs.org',
                        help='Download destination')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check what is missing. No download.')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')
    parser.add_argument('--workers', type=int, default=None,
                        help='Set maximum workers for parallel download (default: cores * 5)')

    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    else:
        logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    downloader = NpmDownloader(args.registry, [args.npm_list, args.output_dir], workers=args.workers)

    if args.check:
        log.info('Check mode. No download will be executed.')
        log.info(downloader.check_table)
        sys.exit(0)

    timer_start = timeit.default_timer()
    try:
        downloader.download()
    except RuntimeError:
        log.error('Error occurred.')
        sys.exit(1)
    finally:
        log.info('Downloading finished in {}'.format(
            datetime.timedelta(seconds=timeit.default_timer() - timer_start)))


if __name__ == '__main__':
    run_cli()
