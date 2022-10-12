#!/usr/bin/env python
'''Return voltha test suites based on criteria.'''

# -----------------------------------------------------------------------
# Copyright 2022 Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -----------------------------------------------------------------------

##-------------------##
##---]  GLOBALS  [---##
##-------------------##

##-------------------##
##---]  IMPORTS  [---##
##-------------------##
from pathlib           import Path
from flog.main         import utils        as main_utils


class Utils():
    """ . """

    ## -----------------------------------------------------------------------
    ## -----------------------------------------------------------------------
    def __init__(self, root=None):
        """Module constructor

        :param data: A data source (often a certificate) to extract hostnames from.
        :type  data: arbitrary

        :raises: ValueError
        """

        return

    ## -----------------------------------------------------------------------
    ## -----------------------------------------------------------------------
    def filecat(self, name:str) -> list:
        '''Slurp contents of a config file in the meta/ directory.

        :param name: Config file name to read.
        :type  name: str
        
        :return: Config file contents with comments and whitespace removed.
        :rtype:  list
        '''
        
        mod_path = Path(__file__).resolve().parent.as_posix()
        meta = Path(mod_path + '/' + name)

        ans = []
        with open(meta, mode='r', encoding='utf-8') as stream:
            for line in stream:
                fields = line.split('#')
                val = fields[0].strip()
                if len(val) > 2:
                    ans += [val]

        return ans
    
    ## -----------------------------------------------------------------------
    ## -----------------------------------------------------------------------
    def get(self, args:list) -> list:
        '''Retrieve a list of tests from a named config file.

        :param args: Config file names to load.
        :type  args: list[str]

        :return: Value(s) loaded from config files.
        :rtype:  list

        ..note: Default beahavior will return an exhaustive list of tests
        ..note: rather than an empty list due to typos.
        '''

        meta = ['olt', 'regression']

        ans = []
        for arg in args:
            if arg in meta:
                ans += self.filecat(arg)
            else:
                ans += self.filecat('all')

        return ans

# [EOF]
