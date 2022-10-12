#!/usr/bin/env python
## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
'''Unit test for meta/voltha.py'''

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
