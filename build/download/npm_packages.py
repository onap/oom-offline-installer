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
import hashlib
import logging
import os
import sys
from retrying import retry

import base

log = logging.getLogger(name=__name__)


@retry(stop_max_attempt_number=5, wait_fixed=5000)
def get_npm(registry, npm_name, npm_version):
    npm_url = '{}/{}/{}'.format(registry, npm_name, npm_version)
    npm_req = base.make_get_request(npm_url)
    npm_json = npm_req.json()
    tarball_url = npm_json['dist']['tarball']
    shasum = npm_json['dist']['shasum']
    tarball_req = base.make_get_request(tarball_url)
    tarball = tarball_req.content
    if hashlib.sha1(tarball).hexdigest() == shasum:
        return tarball
    else:
        raise Exception('{}@{}: Wrong checksum. Retrying...'.format(npm_name, npm_version))


def download_npm(npm, registry, dst_dir):
    log.info('Downloading: {}'.format(npm))
    npm_name, npm_version = npm.split('@')
    dst_path = '{}/{}-{}.tgz'.format(dst_dir, npm_name, npm_version)
    try:
        tarball = get_npm(registry, *npm.split('@'))
        base.save_to_file(dst_path, tarball)
    except Exception as err:
        if os.path.isfile(dst_path):
            os.remove(dst_path)
        log.error('Failed: {}: {}'.format(npm, err))
        raise err
    log.info('Downloaded: {}'.format(npm))


def missing(npm_set, dst_dir):
    return {npm for npm in npm_set
            if not os.path.isfile('{}/{}-{}.tgz'.format(dst_dir, *npm.split('@')))}


def download(npm_list, registry, dst_dir, check_mode, progress=None, workers=None):
    npm_set = base.load_list(npm_list)
    target_count = len(npm_set)
    missing_npms = missing(npm_set, dst_dir)

    if check_mode:
        log.info(base.simple_check_table(npm_set, missing_npms))
        return 0

    skipping = npm_set - missing_npms

    base.start_progress(progress, len(npm_set), skipping, log)
    error_count = base.run_concurrent(workers, progress, download_npm, missing_npms, registry, dst_dir)

    if error_count > 0:
        log.error('{} packages were not downloaded. Check log for specific failures.'.format(error_count))

    base.finish_progress(progress, error_count, log)

    return error_count


def run_cli():
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

    progress = base.init_progress('npm packages') if not args.check else None
    sys.exit(download(args.npm_list, args.registry, args.output_dir, args.check, progress,
                      args.workers))


if __name__ == '__main__':
    run_cli()

