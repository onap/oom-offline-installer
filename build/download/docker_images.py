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
import docker
import itertools
import json
import logging
import os
import prettytable
import sys
import threading
from retrying import retry

import base

log = logging.getLogger(__name__)


def image_filename(image_name):
    """
    Get a name of a file where image will be saved.
    :param image_name: Name of the image from list
    :return: Filename of the image
    """
    return '{}.tar'.format(image_name.replace(':', '_').replace('/', '_'))


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


def not_pulled_images(docker_client, target_list):
    """
    Get set of images that are not pulled on local system.
    :param docker_client: docker.client.DockerClient
    :param target_list: list of images to look for
    :return: (set) images that are not present on local system
    """
    pulled = set(itertools.chain.from_iterable((image.tags for image
                                                in docker_client.images.list())))
    return {image for image in target_list if image_registry_name(image) not in pulled}


def not_saved(target_images, target_dir):
    """
    Get set of images that are not saved in target directory
    :param target_images: List of images to check for
    :param target_dir: Directory where those images should be
    :return: (set) Images that are missing from target directory
    """
    return set(image for image in target_images
               if not os.path.isfile('/'.join((target_dir, image_filename(image)))))


def missing(docker_client, target_list, save, target_dir):
    """
    Get dictionary of images not present locally.
    :param docker_client: docker.client.DockerClient for communication with docker
    :param target_list: list of desired images
    :param save: (boolean) check for saved images
    :param target_dir: target directory for saved images
    :return: Dictionary of missing images ('not_pulled', 'not_saved')
    """
    return {'not_pulled': not_pulled_images(docker_client, target_list),
            'not_saved': not_saved(target_list, target_dir) if save else set()}


def merge_dict_sets(dictionary):
    return set.union(*dictionary.values())


def check_table(check_list, missing, save):
    table = prettytable.PrettyTable(['Image', 'Pulled', 'Saved'])
    table.align['Image'] = 'l'
    for image in sorted(check_list):
        pulled = not image in missing['not_pulled']
        download_state = [pulled]
        if save:
            # if not pulled save anyway
            download_state.append(pulled and not image in missing['not_saved'])
        else:
            download_state.append('Not checked')
        table.add_row([image] + download_state)
    return table


@retry(stop_max_attempt_number=5, wait_fixed=5000)
def pull_image(docker_client, image_name):
    """
    Pull docker image.
    :param docker_client: docker.client.DockerClient for communication with docker
    :param image_name: name of the image to be pulled
    :return: pulled image (image object)
    :raises docker.errors.APIError: after unsuccessful retries
    """
    if ':' not in image_name.rsplit('/')[-1]:
        image_name = '{}:latest'.format(image_name)
    try:
        image = docker_client.images.pull(image_name)
        log.info('Image {} pulled'.format(image_name))
        return image
    except docker.errors.APIError as err:
        log.warning('Failed: {}: {}. Retrying...'.format(image_name, err))
        raise err


def save_image(image_name, image, output_dir, docker_client=None):
    """
    Save image to tar.
    :param output_dir: path to destination directory
    :param image: image object from pull_image function
    :param image_name: name of the image from list
    :param docker_client: docker.client.DockerClient for communication with docker
    :return: None
    """
    dst = '{}/{}'.format(output_dir, image_filename(image_name))
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    if not isinstance(image, docker.models.images.Image):
        image = docker_client.images.get(image_name)
    try:
        with open(dst, 'wb') as f:
            for chunk in image.save(named=image_registry_name(image_name)):
                f.write(chunk)
        log.info('Image {} saved as {}'.format(image_name, dst))
    except Exception as err:
        os.remove(dst)
        raise err


def download_docker_image(image, save, output_dir, docker_client):
    """ Pull and save docker image from specified docker registry
    :param docker_client: docker.client.DockerClient for communication with docker
    :param image: image to be downloaded
    :param save: boolean - save image to disk or skip saving
    :param output_dir: directory where image will be saved
    :return: None
    """
    log.info('Downloading image: {}'.format(image))
    try:
        pulled_image = pull_image(docker_client, image)
        if save:
            save_image(image, pulled_image, output_dir)
    except Exception as err:
        log.error('Error downloading {}: {}'.format(image, err))
        raise err


def download(image_list, save, output_dir, check_mode, progress, workers=3):
    """
    Download images from list
    :param image_list: list of images to be downloaded
    :param save: whether images should be saved to disk
    :param output_dir: directory where images will be saved
    :param check_mode: only check for missing images. No download
    :param progress_bar: progressbar.ProgressBar to show how far download is
    :return: None
    """
    docker_client = docker.client.DockerClient()
    target_images = base.load_list(image_list)
    missing_images = missing(docker_client, target_images, save, output_dir)

    if check_mode:
        log.info(check_table(target_images, missing_images, save))
        return

    skipping = target_images - merge_dict_sets(missing_images)

    base.start_progress(progress, len(target_images), skipping, log)

    # if pulling and save is True. Save every pulled image to assure parity
    futures = base.run_concurrent(workers, download_docker_image, missing_images['not_pulled'],
                                  save, output_dir, docker_client)
    # only save those that are pulled already but not saved
    futures += base.run_concurrent(workers, save_image,
                                   missing_images['not_saved'] - missing_images['not_pulled'],
                                   None, output_dir, docker_client)

    error_count = base.concurrent_wait(futures, progress)

    if error_count > 0:
        log.error('{} images were not downloaded'.format(error_count))
        missing_images = missing(docker_client, target_images, save, output_dir)
        log.info(check_table(merge_dict_sets(missing_images), missing_images, save))

    base.finish_progress(progress, error_count, log)

    return error_count


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

    progress = base.init_progress('Docker images') if not args.check else None
    sys.exit(download(args.image_list, args.save, args.output_dir, args.check,
             progress, args.workers))


if __name__ == '__main__':
    run_cli()

