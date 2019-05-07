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
import os
import requests
import sys
from retrying import retry

#TODO: Logging

def load_list(data_list):
    with open(data_list, 'r') as f:
        return {http_file for http_file in (line.strip() for line in f) if http_file}


@retry(stop_max_attempt_number=5, wait_fixed=2000)
def download_file(file_uri, output_dir):
    print('Downloading: {}'.format(file_uri))
    if not file_uri.startswith('http'):
        file_uri = 'http://' + file_uri

    file_path = output_dir + file_uri.rsplit('//')[-1]
    file_dir = os.path.dirname(file_path)
    try:
        os.makedirs(file_dir)
    except FileExistsError:
        pass
    file_req = requests.get(file_uri)
    # TODO: Maybe checksum
    with open(file_path, 'wb') as dst_file:
        dst_file.write(file_req.content)

def main():
    parser = argparse.ArgumentParser(description='Download http files from list')
    parser.add_argument('file_list', metavar='file-list',
                        help='File with list of http files to download.')

    args = parser.parse_args()
    output_dir = 'test_http/'
    file_set = load_list(args.file_list)
    progress_manager = enlighten.get_manager()
    download_progress = progress_manager.counter(desc='HTTP Files: ')
    download_progress.total = len(file_set)
    download_progress.refresh()


    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = [executor.submit(download_file, f, output_dir) for f in file_set]
        for future in concurrent.futures.as_completed(futures):
            error = future.exception()
            if error is not None:
                print(error)
            else:
                download_progress.update()

    progress_manager.stop()

if __name__ == '__main__':
    main()
