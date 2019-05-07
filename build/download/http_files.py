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
import concurrent.futures
import enlighten
import logging
import os
import requests
import sys
from retrying import retry

log = logging.getLogger(__name__)

def load_list(data_list):
    with open(data_list, 'r') as f:
        return {http_file for http_file in (line.strip() for line in f) if http_file}


@retry(stop_max_attempt_number=5, wait_fixed=2000)
def get_file(file_uri):
    if not file_uri.startswith('http'):
        file_uri = 'http://' + file_uri
    file_req = requests.get(file_uri)
    file_req.raise_for_status()
    return file_req.content


def save_to_file(dst, content):
    dst_dir = os.path.dirname(dst)
    if not os.path.exists(dst_dir):
        os.makedirs(dst_dir)
    with open(dst, 'wb') as dst_file:
        dst_file.write(content)


def download_file(file_uri, output_dir):
    log.info('Downloading: {}'.format(file_uri))
    file_content = get_file(file_uri)
    dst_path = '{}/{}'.format(output_dir, file_uri.rsplit('//')[-1])
    save_to_file(dst_path, file_content)
    return file_uri


def download(data_list, output_dir, progress_bar):
    file_set = load_list(data_list)

    progress_bar.total = len(file_set)
    progress_bar.refresh()

    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = [executor.submit(download_file, f, output_dir) for f in file_set]
        for future in concurrent.futures.as_completed(futures):
            error = future.exception()
            if error is None:
                log.info('Downloaded: {}'.format(future.result()))
                progress_bar.update()
            else:
                log.error(error)


def main():
    parser = argparse.ArgumentParser(description='Download http files from list')
    parser.add_argument('file_list', metavar='file-list',
                        help='File with list of http files to download')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Destination directory for saving')

    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')

    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO, format='%(message)s')

    progress_manager = enlighten.get_manager()
    download_progress = progress_manager.counter(desc='HTTP Files: ')

    download(args.file_list, args.output_dir, download_progress)
    progress_manager.stop()

if __name__ == '__main__':
    main()
