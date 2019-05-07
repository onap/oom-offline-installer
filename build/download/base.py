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


import progressbar
import os
import requests

progressbar.streams.wrap_stdout()
progressbar.streams.wrap_stderr()


def load_list(item_list):
    """
    Parse list with items to be downloaded.
    :param item_list: File with list of items (1 line per item)
    :return: set of items from file
    """
    with open(item_list, 'r') as f:
        return {item for item in (line.strip() for line in f) if item}


def init_progress(items_name):
    progress_widgets = ['Downloading {}: '.format(items_name),
                        progressbar.Bar(), ' ',
                        progressbar.Percentage(), ' ',
                        '(', progressbar.SimpleProgress(), ')']

    progress = progressbar.ProgressBar(widgets=progress_widgets,
                                       poll_rate=1.0,
                                       redirect_stdout=True)
    return progress


def save_to_file(dst, content):
    """
    Save downloaded byte content to file
    :param dst: path to file to save content to
    :param content: byte content of file
    """
    dst_dir = os.path.dirname(dst)
    if not os.path.exists(dst_dir):
        os.makedirs(dst_dir)
    with open(dst, 'wb') as dst_file:
        dst_file.write(content)

def make_get_request(url):
    req = requests.get(url)
    req.raise_for_status()
    return req
