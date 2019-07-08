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

import concurrent.futures
import logging
from abc import ABC, abstractmethod

from downloader import AbstractDownloader

log = logging.getLogger(__name__)


class ConcurrentDownloader(AbstractDownloader, ABC):
    def __init__(self, list_type, *list_args, workers=None):
        super().__init__(list_type, *list_args)
        self._workers = workers

    @abstractmethod
    def _download_item(self, item):
        """
        Download item from list
        :param item: item to be downloaded
        """
        pass

    def download(self):
        """
        Download images concurrently from data lists.
        """
        if not self._initial_log():
            return
        items_left = len(self._missing)
        try:
            for _ in self.run_concurrent(self._download_item, self._missing.items()):
                items_left -= 1
                log.info('{} {} left to download.'.format(items_left, self._list_type))
        except RuntimeError as err:
            log.error('{} {} were not downloaded.'.format(items_left, self._list_type))
            raise err

    def run_concurrent(self, fn, iterable, *args):
        """
        Run function concurrently for iterable
        :param fn: function to run
        :param iterable: iterable to process
        :param args: arguments for function (fn)
        """
        with concurrent.futures.ThreadPoolExecutor(max_workers=self._workers) as executor:
            futures = [executor.submit(fn, item, *args) for item in iterable]
            error_occurred = False

            for future in concurrent.futures.as_completed(futures):
                error = future.exception()
                if error:
                    error_occurred = True
                else:
                    yield
            if error_occurred:
                raise RuntimeError('One or more errors occurred')
