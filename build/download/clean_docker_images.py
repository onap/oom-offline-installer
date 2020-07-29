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
import docker
import logging
import sys

from downloader import AbstractDownloader
from docker_downloader import DockerDownloader


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('image_lists', nargs='+', help='Images to keep')
    parser.add_argument('--debug', '-d', action='store_true', help='Debugging messages')
    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level=logging.DEBUG, stream=sys.stdout)
    else:
        logging.basicConfig(level=logging.INFO, stream=sys.stdout, format='%(message)s')

    target = set()
    for lst in args.image_lists:
        target = target.union(AbstractDownloader.load_list(lst))

    target = set(map(DockerDownloader.image_registry_name, target))

    client = docker.client.DockerClient(version='auto')

    errors = 0
    for image in client.images.list():
        for tag in image.tags:
            logging.debug('Checking {}'.format(tag))
            if tag not in target:
                logging.debug('Image \'{}\' not in lists'.format(tag))
                logging.info('Removing: {}'.format(tag))
                try:
                    client.images.remove(tag)
                    logging.info('Removed: {}'.format(tag))
                except docker.errors.APIError as err:
                    errors += 1
                    logging.exception(err)
            else:
                logging.debug('Image \'{}\' found in lists.'.format(tag))
    sys.exit(errors)


if __name__ == '__main__':
    main()
