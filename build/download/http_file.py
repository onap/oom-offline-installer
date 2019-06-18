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

import os


class HttpFile:
    """
    File to be saved
    """
    def __init__(self, name, content, dst):
        self._name = name
        self._content = content
        self._dst = dst

    @property
    def name(self):
        """
        Name of the file
        """
        return self._name

    def save_to_file(self):
        """
        Save it to disk
        """
        dst_dir = os.path.dirname(self._dst)
        if not os.path.exists(dst_dir):
            os.makedirs(dst_dir)
        with open(self._dst, 'wb') as dst_file:
            dst_file.write(self._content)
