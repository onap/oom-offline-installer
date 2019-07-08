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
import logging
import sys
import timeit

import docker_downloader
import git_downloader
import http_downloader
import npm_downloader
import pypi_downloader
import rpm_downloader

log = logging.getLogger(name=__name__)


def parse_args():
    """
    Parse command line arguments
    :return: arguments
    """
    parser = argparse.ArgumentParser(description='Download data from lists')
    list_group = parser.add_argument_group()
    list_group.add_argument('--docker', action='append', nargs='+', default=[],
                            metavar=('list', 'dir-name'),
                            help='Docker type list. If second argument is specified '
                                 'it is treated as directory where images will be saved '
                                 'otherwise only pull operation is executed this can\'t '
                                 'be mixed between multiple docker list specifications. '
                                 'if one of the list does not have directory specified '
                                 'all lists are only pulled!!!')
    list_group.add_argument('--http', action='append', nargs=2, default=[],
                            metavar=('list', 'dir-name'),
                            help='Http type list and directory to save downloaded files')
    list_group.add_argument('--npm', action='append', nargs=2, default=[],
                            metavar=('list', 'dir-name'),
                            help='npm type list and directory to save downloaded files')
    list_group.add_argument('--rpm', action='append', nargs=2, default=[],
                            metavar=('list', 'dir-name'),
                            help='rpm type list and directory to save downloaded files')
    list_group.add_argument('--git', action='append', nargs=2, default=[],
                            metavar=('list', 'dir-name'),
                            help='git repo type list and directory to save downloaded files')
    list_group.add_argument('--pypi', action='append', nargs=2, default=[],
                            metavar=('list', 'dir-name'),
                            help='pypi packages type list and directory to save downloaded files')
    parser.add_argument('--npm-registry', default='https://registry.npmjs.org',
                        help='npm registry to use (default: https://registry.npmjs.org)')
    parser.add_argument('--check', '-c', action='store_true', default=False,
                        help='Check what is missing. No download.')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')

    args = parser.parse_args()

    for arg in ('docker', 'npm', 'http', 'rpm', 'git', 'pypi'):
        if getattr(args, arg):
            return args

    parser.error('One of --docker, --npm, --http, --rpm, --git or --pypi must be specified')


def log_start(item_type):
    """
    Log starting message
    :param item_type: type of resources
    :return:
    """
    log.info('Starting download of {}.'.format(item_type))


def handle_download(downloader, check_mode, errorred_lists, start_time):
    """
    Handle download of resources
    :param downloader: downloader to use
    :param check_mode: run in check mode (boolean)
    :param errorred_lists: list of data types of failed lists
    :param start_time: timeit.default_timer() right before download
    :return: timeit.default_timer() at the end of download
    """
    if check_mode:
        print(downloader.check_table)
    else:
        log_start(downloader.list_type)
        try:
            downloader.download()
        except RuntimeError:
            errorred_lists.append(downloader.list_type)
    return log_time_interval(start_time, downloader.list_type)


def handle_command_download(downloader_class, check_mode, errorred_lists, start_time, *args):
    """
    Handle download of resources where shell command is used
    :param downloader_class: Class of command_downloader.CommandDownloader to use
    :param check_mode: run in check mode (boolean)
    :param errorred_lists: list of data types of failed lists
    :param start_time: timeit.default_timer() right before download
    :param args: arguments for downloader class initialization
    :return: timeit.default_timer() at the end of download
    """
    try:
        downloader = downloader_class(*args)
        return handle_download(downloader, check_mode, errorred_lists, start_time)
    except FileNotFoundError as err:
        classname = type(downloader_class).__name__
        log.exception('Error initializing: {}: {}'.format(classname, err))
    return timeit.default_timer()


def log_time_interval(start, resource_type=''):
    """
    Log how long the download took
    :param start: timeit.default_timer() when interval started
    :param resource_type: type of data that was downloaded. (empty string for whole download)
    :return: timeit.default_timer() after logging
    """
    e_time = datetime.timedelta(seconds=timeit.default_timer() - start)
    if resource_type:
        msg = 'Download of {} took {}\n'.format(resource_type, e_time)
    else:
        msg = 'Execution ended. Total elapsed time {}'.format(e_time)
    log.info(msg)
    return timeit.default_timer()


def run_cli():
    if sys.version_info.major < 3:
        log.error('Unfortunately Python 2 is not supported for data download.')
        sys.exit(1)
    args = parse_args()

    console_handler = logging.StreamHandler(sys.stdout)
    console_formatter = logging.Formatter('%(message)s')
    console_handler.setFormatter(console_formatter)
    now = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    log_file = 'download_data-{}.log'.format(now)
    file_format = "%(asctime)s: %(filename)s: %(levelname)s: %(message)s"

    if args.debug:
        logging.basicConfig(level=logging.DEBUG, filename=log_file, format=file_format)
    else:
        logging.basicConfig(level=logging.INFO, filename=log_file, format=file_format)
    root_logger = logging.getLogger()
    root_logger.addHandler(console_handler)

    errorred_lists = []
    timer_start = interval_start = timeit.default_timer()

    if args.check:
        log.info('Check mode. No download will be executed.')

    if args.docker:
        save = True if len(list(filter(lambda x: len(x) == 2, args.docker))) == len(args.docker) else False
        docker = docker_downloader.DockerDownloader(save, *args.docker, workers=3)
        interval_start = handle_download(docker, args.check, errorred_lists, interval_start)

    if args.http:
        http = http_downloader.HttpDownloader(*args.http)
        interval_start = handle_download(http, args.check, errorred_lists, interval_start)

    if args.npm:
        npm = npm_downloader.NpmDownloader(args.npm_registry, *args.npm)
        interval_start = handle_download(npm, args.check, errorred_lists, interval_start)

    if args.rpm:
        interval_start = handle_command_download(rpm_downloader.RpmDownloader, args.check, errorred_lists,
                                                 interval_start, *args.rpm)

    if args.git:
        interval_start = handle_command_download(git_downloader.GitDownloader, args.check, errorred_lists,
                                                 interval_start, *args.git)

    if args.pypi:
        handle_command_download(pypi_downloader.PyPiDownloader, args.check, errorred_lists,
                                interval_start, *args.pypi)

    if not args.check:
        log_time_interval(timer_start)

    if errorred_lists:
        log.error('Errors encountered while processing these types:'
                  '\n{}'.format('\n'.join(errorred_lists)))
        sys.exit(1)


if __name__ == '__main__':
    run_cli()
