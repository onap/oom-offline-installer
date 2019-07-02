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
from abc import ABC, abstractmethod

import prettytable

log = logging.getLogger(__name__)


class AbstractDownloader(ABC):

    def __init__(self, list_type, *list_args):
        self._list_type = list_type
        self._data_list = {item: list_arg[1] for list_arg in list_args
                           for item in self.load_list(list_arg[0])}
        self._missing = self.missing()

    @property
    def list_type(self):
        """
        Type of resource in list
        """
        return self._list_type

    @staticmethod
    def load_list(path):
        """
        Load list from file.
        :param path: path to file
        :return: set of items in list
        """
        with open(path, 'r') as f:
            return {item for item in (line.strip() for line in f)
                    if item and not item.startswith('#')}

    @staticmethod
    def _check_table(header, alignment_dict, data):
        """
        General method to generate table
        :param header: header of the table
        :param alignment_dict: dictionary with alignment for columns
        :param data: iterable of rows of table
        :return: table formatted data
        """
        table = prettytable.PrettyTable(header)

        for k, v in alignment_dict.items():
            table.align[k] = v

        for row in sorted(data):
            table.add_row(row)

        return table

    @abstractmethod
    def download(self):
        """
        Download resources from lists
        """
        pass

    @abstractmethod
    def _is_missing(self, item):
        """
        Check if item is not downloaded
        """
        pass

    def missing(self):
        """
        Check for missing data (not downloaded)
        :return: dictionary of missing items
        """
        self._missing = {item: dst for item, dst in self._data_list.items() if
                         self._is_missing(item)}
        return self._missing

    def _log_existing(self):
        """
        Log items that are already downloaded.
        """
        for item in self._merged_lists():
            if item not in self._missing:
                if type(self).__name__ == 'DockerDownloader':
                    log.info('Docker image present: {}'.format(item))
                else:
                    log.info('File or directory present: {}'.format(item))

    def _merged_lists(self):
        """
        Get all item names in one set
        :return: set with all items
        """
        return set(self._data_list.keys())

    def _initial_log(self):
        """
        Log initial info for download.
        :return: True if download is necessary False if everything is already downloaded
        """
        self._log_existing()
        items_left = len(self._missing)
        class_name = type(self).__name__
        if items_left == 0:
            log.info('{}: Everything seems to be present no download necessary.'.format(class_name))
            return False
        log.info('{}: Initializing download {} {} are not present.'.format(class_name, items_left,
                                                                           self._list_type))
        return True
