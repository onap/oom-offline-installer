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

#   COPYRIGHT NOTICE ENDS HEREE

import argparse
import subprocess
import logging
import sys
import os
from retrying import retry

import base

log = logging.getLogger(name=__name__)

@retry(stop_max_attempt_number=5, wait_fixed=5000)
def clone_repo(dst, repo, branch=None):
    if branch:
        command = 'git clone -b {} --single-branch https://{} --bare {}'.format(branch, repo, dst)
    else:
        command = 'git clone https://{} --bare {}'.format(repo, dst)
    log.info('Running: {}'.format(command))
    log.info(subprocess.check_output(command.split(), stderr=subprocess.STDOUT).decode())
    log.info('Downloaded: {}'.format(repo))


def download(git_list, dst_dir, progress):
    git_set = {tuple(item.split()) for item in base.load_list(git_list)
               if not item.startswith('#')}

    error_count = 0

    base.start_progress(progress, len(git_set), [], log)

    for repo in git_set:
        dst = '{}/{}'.format(dst_dir, repo[0])
        if os.path.isdir(dst):
            log.warning('Directory {} already exists. Repo probably present'.format(dst))
            progress.update(progress.value + 1)
            continue
        try:
            clone_repo(dst, *repo)
            progress.update(progress.value + 1)
        except subprocess.CalledProcessError as err:
            log.error(err.output.decode())
            error_count += 1

    base.finish_progress(progress, error_count, log)
    if error_count > 0:
        log.error('{} were not downloaded. Check logs for details'.format(error_count))
    return error_count


def run_cli():
    parser = argparse.ArgumentParser(description='Download git repositories from list')
    parser.add_argument('git_list', metavar='git-list',
                        help='File with list of npm packages to download.')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')

    args = parser.parse_args()

    logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    progress = base.init_progress('git repositories')

    sys.exit(download(args.git_list, args.output_dir, progress))


if __name__ == '__main__':
    run_cli()
