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
import sys
import timeit

import requests
from retrying import retry

import http_file
from concurrent_downloader import ConcurrentDownloader

log = logging.getLogger(__name__)


class HttpDownloader(ConcurrentDownloader):
    def __init__(self, *list_args, list_type='http_files', workers=None):
        super().__init__(list_type, *list_args, workers=workers)

    @property
    def check_table(self):
        """
        Table with information what items from lists are downloaded
        """
        self.missing()
        header = ['Name', 'Downloaded']
        return self._check_table(header, {'Name': 'l'},
                                 ((item, item not in self._missing) for item
                                  in self._data_list))

    @staticmethod
    def _make_get_request(url):
        """
        Run http get request
        :param url: url to reqeuest
        :return: requests.Response
        """
        req = requests.get(url)
        req.raise_for_status()
        return req

    def _is_missing(self, item):
        """
        Check if item is missing (not downloaded)
        :param item: item to check
        :return: boolean
        """
        return not os.path.isfile(
            '{}/{}'.format(self._data_list[item], item.rsplit('//')[-1]))

    @retry(stop_max_attempt_number=5, wait_fixed=2000)
    def _get_file(self, file_uri):
        """
        Get http file from uri
        :param file_uri: uri of the file
        :return: file content
        """
        if not file_uri.startswith('http'):
            file_uri = 'http://' + file_uri
        file_req = self._make_get_request(file_uri)
        return file_req.content

    def _download_item(self, item):
        """
        Download http file
        :param item: http file to be downloaded (tuple: (uri, dst_dir))
        """
        log.info('Downloading: {}'.format(item[0]))
        dst_path = '{}/{}'.format(item[1], item[0].rsplit('//')[-1])
        try:
            f = http_file.HttpFile(item[0], self._get_file(item[0]), dst_path)
            f.save_to_file()
        except Exception as err:
            log.exception('Error downloading: {}: {}'.format(item[0], err))
            if os.path.isfile(dst_path):
                os.remove(dst_path)
            raise err
        log.info('Downloaded: {}'.format(f.name))


def run_cli():
    """
    Run as cli tool
    """
    parser = argparse.ArgumentParser(description='Download http files from list')
    parser.add_argument('file_list', metavar='file-list',
                        help='File with list of http files to download')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Destination directory for saving')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check mode')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')
    parser.add_argument('--workers', type=int, default=None,
                        help='Set maximum workers for parallel download (default: cores * 5)')

    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    else:
        logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    downloader = HttpDownloader([args.file_list, args.output_dir], workers=args.workers)

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
