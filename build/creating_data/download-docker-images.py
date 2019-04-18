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
import os
import sys
import docker
import argparse
from multiprocessing import Process
from retrying import retry


def load_list(image_list):
    images = dict()
    with open(image_list, 'r') as f:
        for image in (line.strip().rsplit(':',1) for line in f):
            images.setdefault(image[0], []).append(image[1])
    return images

@retry(stop_max_attempt_number=5, wait_fixed=5000)
def pull_image(docker_client, image_name, image_tag):
    try:
        return docker_client.images.pull(':'.join([image_name, image_tag]))
    except docker.errors.APIError as err:
        sys.stderr.write('Failed: {}. Retrying...'.format(err))
        raise err

def save_image(dest, image, name_tag):
    with open(dest, 'wb') as f:
        for chunk in image.save(named=name_tag):
            f.write(chunk)

def download_docker_images(image_list, save, output_dir):
    docker_client = docker.client.DockerClient()

    process_pool = []
    images = load_list(image_list)
    images_total = sum((len(tags) for tags in images.values()))
    image_count = 0

    for image, tags in images.items():
        for tag in tags:
            image_count += 1
            print('Pulling image: {}:{} ({}/{})'.format(image, tag,
                image_count, images_total))
            pulled_image = pull_image(docker_client, image, tag)
        if save:
            tag_name = ':'.join((image, tag))
            tar_name = '{}.tar'.format(tag_name.replace(':', '_').replace('/', '_'))
            print('Saving image {} as {}'.format(tag_name, tar_name))
            process = Process(target=save_image, args=(tar_name, pulled_image, tag_name))
            process_pool.append(process)
            process.start()

    for process in process_pool:
        process.join()


def run():
    parser = argparse.ArgumentParser(description='Download docker images from list')
    parser.add_argument('image_list', help='File with list of images to download.')
    parser.add_argument('--save', '-s', action='store_true', default=False,
            help='Save images (without it only pull is executed)')
    parser.add_argument('--output-dir', '-o', default=os.getcwd(),
            help='Download destination')

    args = parser.parse_args()

    download_docker_images(args.image_list, args.save, args.output_dir)

if __name__ == '__main__':
    run()

