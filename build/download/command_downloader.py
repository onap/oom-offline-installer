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

import logging
import subprocess
from abc import abstractmethod
from distutils.spawn import find_executable

import downloader

log = logging.getLogger(__name__)


class CommandDownloader(downloader.AbstractDownloader):
    def __init__(self, list_type, cli_tool, *list_args):
        super().__init__(list_type, *list_args)
        if not find_executable(cli_tool):
            raise FileNotFoundError(cli_tool)

    def download(self):
        """
        Download items from list
        """
        if not self._initial_log():
            return
        items_left = len(self._missing)
        error_occurred = False
        for item, dst_dir in self._data_list.items():
            try:
                self._download_item((item, dst_dir))
            except subprocess.CalledProcessError as err:
                log.exception(err.output.decode())
                error_occurred = True
            items_left -= 1
            log.info('{} {} left to download.'.format(items_left, self._list_type))
        if error_occurred:
            log.error('{} {} were not downloaded.'.format(items_left, self._list_type))
            raise RuntimeError('One or more errors occurred')

    def _download_item(self, item):
        pass
