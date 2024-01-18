#!/usr/bin/env python
'''This script is an aggregate for testing resources.'''

# -----------------------------------------------------------------------
# Copyright 2022-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
import sys
import pprint

from flog.main        import utils           as main_utils
from flog.main        import argparse        as main_getopt

# from flog.meta        import onos
from flog.meta        import voltha

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
def process():
    '''Perform actions based on command line args.'''

    argv  = main_getopt.get_argv()
    debug = argv['debug']
    trace = argv['trace']

    todos = [] 

    ## -----------------------------
    ## Accumulate tests by attribute
    ## -----------------------------
    for attr in argv['attr']:
        if debug:
            print('** ATTR: %s' % attr)
        todos += voltha.Utils().get([attr])

    ## ------------------------
    ## Accumulate tests by type
    ## ------------------------
    for test_type in argv['type']:
        if debug:
            print('** TYPE: %s' % test_type)
        todos += voltha.Utils().get([test_type])

    ## ---------------------------------------
    ## Append an explicit list of tests to run
    ## ---------------------------------------
    for incl in argv['incl']:
        if debug:
            print('** INCL: %s' % incl)
        todos += [incl]

    ## -------------------------------------
    ## Filter results by substring or config
    ## -------------------------------------
    # if len(argv['excl']) > 1:
    #    for excl in argv['excl']:
    #        if any([excl in val for val in todos]):
    #            continue
    #        

    todos = list(set(todos)) # unique

    # -------------------------------------
    # Err on the side of testing everything
    # -------------------------------------
    if len(todos) == 0: 
        todos += voltha.Utils().get(['all'])
       
    for todo in todos:
        print(todo)

    return


## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
def main(argv_raw):
    '''Here we go.'''

    main_getopt.getopts(argv_raw)
    process()
    sys.exit(0)

##----------------##
##---]  MAIN  [---##
##----------------##
if __name__ == "__main__":
    main(sys.argv[1:]) # NOSONAR

# [EOF]
