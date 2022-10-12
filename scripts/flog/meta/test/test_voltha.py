#!/usr/bin/env python
'''Unit test for meta/voltha.py'''

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
import unittest

from flog.main         import utils           as main_utils
from flog.meta         import voltha


class TestStringMethods(unittest.TestCase):

    ## -----------------------------------------------------------------------
    ## -----------------------------------------------------------------------
    def test_by_all(self):
        '''Verify result of default test lookup.'''

        exp = ['https://jenkins.opencord.org/view/VOLTHA-2.X-Tests/']
        for arg in ['all', 'invalid']:
            got = voltha.Utils().get([arg])
            self.assertCountEqual(got, exp)
            
    ## -----------------------------------------------------------------------
    ## -----------------------------------------------------------------------
    def test_by_olt(self):
        '''Verify result of test lookup by string arg 'olt'.''' 

        exp = 'periodic-voltha-multi-uni-multiple-olts-test-bbsim'
        for arg in ['olt']:
            got = voltha.Utils().get([arg])
            self.assertEqual(len(got), 1)
            self.assertIn(exp, got[0])

    ## -----------------------------------------------------------------------
    ## -----------------------------------------------------------------------
    def test_by_regression(self):
        '''Verify result of test lookup by string arg 'regression.'''

        for arg in ['regression']:
            got = voltha.Utils().get([arg])
            self.assertTrue(len(got) > 2)
        
##----------------##
##---]  MAIN  [---##
##----------------##
if __name__ == "__main__":
    main()

# [EOF]
