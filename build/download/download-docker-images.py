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


from __future__ import print_function

import argparse
import concurrent.futures
import docker
import enlighten
import itertools
import os
import sys
import threading
from retrying import retry


def load_list(image_list):
    images = set()
    with open(image_list, 'r') as f:
        return set(image for image in (line.strip() for line in f) if image)


def image_filename(image_name):
    return '{}.tar'.format(image_name.replace(':', '_').replace('/', '_'))


def not_pulled(docker_client, target_list):
    pulled = set(itertools.chain.from_iterable((image.tags for image
                                                in docker_client.images.list())))

    return set(image for image in target_list if image not in pulled)


def not_saved(target_images, target_dir):
    return set(image for image in target_images
               if not os.path.isfile('/'.join((target_dir, image_filename(image)))))


def missing_images(docker_client, target_list,  save, target_dir):
    return {'not_pulled': not_pulled(docker_client, target_list),
            'not_saved': not_saved(target_list, target_dir) if save else {}}


@retry(stop_max_attempt_number=5, wait_fixed=5000)
def pull_image(docker_client, full_image_name):
    try:
        return docker_client.images.pull(full_image_name)
    except docker.errors.APIError as err:
        print('Failed: {}. Retrying...'.format(err))
        raise err


def save_image(output_dir, image_name, image=image_name, docker_client=None):
    dst = '{}/{}'.format(output_dir, image_filename(image_name))
    if not isinstance(image, docker.models.images.Image):
        image = docker_client.images.get(image_name)
    with open(dst, 'wb') as f:
        for chunk in image.save(named=image_name):
            f.write(chunk)
        return dst


def download_docker_image(docker_client, image, save, output_dir):
    #TODO: LOGGING
    print('Downloading image: {} '.format(image))
    pulled_image = pull_image(docker_client, image)
    if save:
        dst = save_image(output_dir, pulled_image, image)

    return image, dst_file if save else False


def download(image_list, save, output_dir, progress_bar):
    docker_client = docker.client.DockerClient()
    target_images = load_list(image_list)
    target_count = len(target_images)
    progress_bar.total = target_count
    missing = missing_images(docker_client, target_images, save, output_dir)
    progress_bar.count = target_count - len(missing['not_saved'].union(missing['not_pulled']))
    progress_bar.refresh()
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = [executor.submit(
                                   download_docker_image,
                                   docker_client, image, image in missing['not_saved'],
                                   output_dir)
                   for image in missing['not_pulled']]
        futures += [executor.submit(save_image,
                                    output_dir, image, image, docker_client)
                    for image in missing['not_saved'] - missing['not_pulled']]
        for future in concurrent.futures.as_completed(futures):
            error =  future.exception()
            progress_bar.update()
            if error is None:
                result = future.result()
                if save:
                    print('Image {} saved as {}'.format(result[0], result[1]))
                else:
                    print('Image {} pulled'.format(result[0]))
                print(result)
            else:
                print(error)
# TODO: EXCEPTION HANDLE

def run():
    parser = argparse.ArgumentParser(description='Download docker images from list')
    parser.add_argument('image_list', help='File with list of images to download.')
    parser.add_argument('--save', '-s', action='store_true', default=False,
                        help='Save images (without it only pull is executed)')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
                        help='Download destination')

    args = parser.parse_args()

    progress_manager = enlighten.get_manager()
    download_progress = progress_manager.counter(desc='Images:')
    download(args.image_list, args.save, args.output_dir, download_progress)
    progress_manager.stop()

if __name__ == '__main__':
    run()
