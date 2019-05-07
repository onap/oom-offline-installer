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
import logging
import os
import sys
from retrying import retry

import base

log = logging.getLogger(__name__)

@retry(stop_max_attempt_number=5, wait_fixed=2000)
def get_file(file_uri):
    """
    Get file from the Internet
    :param file_uri: address of file
    :return: byte content of file
    """
    if not file_uri.startswith('http'):
        file_uri = 'http://' + file_uri
    file_req = base.make_get_request(file_uri)
    return file_req.content


def download_file(file_uri, dst_dir):
    """
    Download http file and save it to file.
    :param file_uri: http address of file
    :param dst_dir: directory where file will be saved
    """
    log.info('Downloading: {}'.format(file_uri))
    dst_path = '{}/{}'.format(dst_dir, file_uri.rsplit('//')[-1])
    try:
        file_content = get_file(file_uri)
        base.save_to_file(dst_path, file_content)
    except Exception as err:
        if os.path.isfile(dst_path):
            os.remove(dst_path)
        log.error('Error downloading: {}: {}'.format(file_uri, err))
        raise err
    log.info('Downloaded: {}'.format(file_uri))


def missing(file_set, dst_dir):
    return {file for file in file_set if not os.path.isfile('{}/{}'.format(dst_dir, file))}


def download(data_list, dst_dir, check, progress, workers=None):
    """
    Download files specified in data list
    :param data_list: path to file with list
    :param dst_dir: destination directory
    :param check: boolean check mode
    :param progress: progressbar.ProgressBar to monitor progress
    :param workers: workers to use for parallel execution
    :return: 0 if success else number of errors
    """
    file_set = base.load_list(data_list)
    missing_files = missing(file_set, dst_dir)
    target_count = len(file_set)

    if check:
        log.info(base.simple_check_table(file_set, missing_files))
        return 0

    skipping = file_set - missing_files

    base.start_progress(progress, len(file_set), skipping, log)

    futures = base.run_concurrent(workers, download_file, missing_files, dst_dir)
    error_count = base.concurrent_wait(futures, progress)

    if error_count > 0:
        log.error('{} files were not downloaded. Check log for specific failures.'.format(error_count))

    base.finish_progress(progress, error_count, log)

    return error_count

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

    progress = base.init_progress('http files') if not args.check else None

    sys.exit(download(args.file_list, args.output_dir, args.check, progress, args.workers))


if __name__ == '__main__':
    run_cli()

