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
import itertools
import logging
import os
import sys
import timeit

import docker
from retrying import retry

from concurrent_downloader import ConcurrentDownloader

log = logging.getLogger(__name__)


class DockerDownloader(ConcurrentDownloader):
    def __init__(self, save, *list_args, workers=3):
        self._save = save
        try:
            # big timeout in case of massive images like pnda-mirror-container:5.0.0 (11.4GB)
            self._docker_client = docker.from_env(timeout=300)
        except docker.errors.DockerException as err:
            log.exception(
                'Error creating docker client. Check if is docker installed and running'
                ' or if you have right permissions.')
            raise err
        self._pulled_images = set(itertools.chain.from_iterable((image.tags for image
                                                                 in self._docker_client.images.list())))
        list_args = ([*x, None] if len(x) < 2 else x for x in list_args)
        super().__init__('docker images', *list_args, workers=workers)

    @staticmethod
    def image_registry_name(image_name):
        """
        Get the name as shown in local registry. Since some strings are not part of name
        when using default registry e.g. docker.io
        :param image_name: name of the image from the list
        :return: name of the image as it is shown by docker
        """
        name = image_name

        if name.startswith('docker.io/'):
            name = name.replace('docker.io/', '')

        if name.startswith('library/'):
            name = name.replace('library/', '')

        if ':' not in name.rsplit('/')[-1]:
            name = '{}:latest'.format(name)

        return name

    @property
    def check_table(self):
        """
        Table showing information of which images are pulled/saved
        """
        self.missing()
        return self._table(self._data_list)

    @property
    def fail_table(self):
        """
        Table showing information about state of download of images
        that encountered problems while downloading
        """
        return self._table(self.missing())

    @staticmethod
    def _image_filename(image_name):
        """
        Get a name of a file where image will be saved.
        :param image_name: Name of the image from list
        :return: Filename of the image
        """
        return '{}.tar'.format(image_name.replace(':', '_').replace('/', '_'))

    def _table(self, images):
        """
        Get table in format for images
        :param images: images to put into table
        :return: check table format with specified images
        """
        header = ['Name', 'Pulled', 'Saved']
        data = []
        for item in images:
            if item not in self._missing:
                data.append((item, True, True if self._save else 'N/A'))
            else:
                data.append((item, self._missing[item]['pulled'], self._missing[item]['saved']))
        return self._check_table(header, {'Name': 'l'}, data)

    def _is_pulled(self, image):
        return self.image_registry_name(image) in self._pulled_images

    def _is_saved(self, image):
        dst = '{}/{}'.format(self._data_list[image], self._image_filename(image))
        return os.path.isfile(dst)

    def _is_missing(self, item):
        """
        Missing docker images are checked slightly differently.
        """
        pass

    def missing(self):
        """
        Get dictionary of images not present locally.
        """
        missing = dict()
        for image, dst in self._data_list.items():
            pulled = self._is_pulled(image)
            if self._save:
                # if pulling and save is True. Save every pulled image to assure parity
                saved = False if not pulled else self._is_saved(image)
            else:
                saved = 'N/A'
            if not pulled or not saved:
                missing[image] = {'dst': dst, 'pulled': pulled, 'saved': saved}
        self._missing = missing
        return self._missing

    @retry(stop_max_attempt_number=5, wait_fixed=5000)
    def _pull_image(self, image_name):
        """
        Pull docker image.
        :param image_name: name of the image to be pulled
        :return: pulled image (image object)
        :raises docker.errors.APIError: after unsuccessful retries
        """
        if ':' not in image_name.rsplit('/')[-1]:
            image_name = '{}:latest'.format(image_name)
        try:
            image = self._docker_client.images.pull(image_name)
            log.info('Image {} pulled'.format(image_name))
            return image
        except docker.errors.APIError as err:
            log.warning('Failed: {}: {}. Retrying...'.format(image_name, err))
            raise err

    def _save_image(self, image_name, image, output_dir):
        """
        Save image to tar.
        :param output_dir: path to destination directory
        :param image: image object from pull_image function
        :param image_name: name of the image from list
        """
        dst = '{}/{}'.format(output_dir, self._image_filename(image_name))
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        try:
            with open(dst, 'wb') as f:
                for chunk in image.save(named=self.image_registry_name(image_name)):
                    f.write(chunk)
            log.info('Image {} saved as {}'.format(image_name, dst))
        except Exception as err:
            if os.path.isfile(dst):
                os.remove(dst)
            raise err

    def _download_item(self, image):
        """ Pull and save docker image from specified docker registry
        :param image: image to be downloaded
        """
        image_name, image_dict = image
        log.info('Downloading image: {}'.format(image_name))
        try:
            if image_dict['pulled']:
                image_to_save = self._docker_client.images.get(image_name)
            else:
                image_to_save = self._pull_image(image_name)
            if self._save:
                self._save_image(image_name, image_to_save, image_dict['dst'])
        except Exception as err:
            log.exception('Error downloading {}: {}'.format(image_name, err))
            raise err


def run_cli():
    parser = argparse.ArgumentParser(description='Download docker images from list')
    parser.add_argument('image_list', metavar='image-list',
                        help='File with list of images to download.')
    parser.add_argument('--save', '-s', action='store_true', default=False,
                        help='Save images (without it only pull is executed)')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check what is missing. No download.'
                             'Use with combination with -s to check saved images as well.')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')
    parser.add_argument('--workers', type=int, default=3,
                        help='Set maximum workers for parallel download (default: 3)')

    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    else:
        logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    downloader = DockerDownloader(args.save, [args.file_list, args.output_dir], workers=args.workers)

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
