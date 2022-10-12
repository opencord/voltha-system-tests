# -*- python -*-
'''A module for parsing script command line arguments.

..seealso: https://docs.python.org/3/library/argparse.html##
'''

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
ARGV      = None
namespace = None

##-------------------##
##---]  IMPORTS  [---##
##-------------------##
import argparse

from flog.main        import utils              as main_utils
from flog.main        import help            as main_help

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
def get_argv():
    """Retrieve parsed command line switches.

    ..pre: getopts() was called earlier.

    :return: Parsed command line argument storage
    :rtype : dict
    """

    global ARGV
    global namespace

    if ARGV is None:
        # Normalize argspace/namespace into a getopt/dictionary
        # Program wide syntax edits needed: args['foo'] => args.foo
        arg_dict = {}
        for arg in vars(namespace):
            arg_dict[arg] = getattr(namespace, arg)
        ARGV = arg_dict

    return ARGV

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
def getopts(argv, debug=None) -> None:
    """Parse command line args, check options and pack into a hashmap

    :param argv: values passed on the command line
    :param debug: optional flag to enable debug mode

    :return: Digested command line arguments
    :rtype : dict

    :raises  ValueError

    .. versionadded:: 1.0
    """

    global namespace

    iam = main_utils.iam()

    if debug is None:
        debug = False

    parser = argparse.ArgumentParser\
             (
                 description = '''Report test dependencies based on selection criteria.'''
                 # epilog = 'extra-help-text'
             )

    ## -----------------------------------------------------------------------
    ## [TEST: categories]
    ## -----------------------------------------------------------------------
    parser.add_argument('--attr',
                        action  = 'append',
                        default = [],
                        choices=\
                        [
                            'olt',   # optical line termination
                            #
                            'onu',   # optical network unit
                            #
                            'epon',
                            'pon',   # passive optical network
                            'gpon',  # gigabit-pon
                            'xpon',
                        ],
                        help = 'Enable testing by attribute',
                    )

    ## -----------------------------------------------------------------------
    ## [TEST:types]
    ## -----------------------------------------------------------------------
    parser.add_argument('--type',
                        action  = 'append',
                        default = [],
                        choices=\
                        [
                            'burnin',       # profile, stress testing
                            'integration',  # trigger inter-dependencies
                            'oink',         # kitchen sink testing
                            'regression',   # have we broken the renaissance ?
                            'scale',        #
                            'system',       #
                            'smoke',        # quick: 60s > [n]
                            'standalone',   # dependency-less tests
                            'suite',        #
                            'unit',         # module/api/narrow focus.
                        ],
                        help = 'Enable testing by category',
                    )

    ## -----------------------------------------------------------------------
    ## [FILTER]
    ## -----------------------------------------------------------------------
    parser.add_argument('--excl',
                        action  = 'append',
                        default = [],
                        help    = 'FILTER: Probe resources to exclude',
                    )
    parser.add_argument('--incl',
                        action  = 'append',
                        default = [],
                        help    = 'FILTER: Probe resources to include',
                    )

    ## -----------------------------------------------------------------------
    ## [MODES]
    ## -----------------------------------------------------------------------
    parser.add_argument('--debug',
                        action  = 'store_true',
                        default = False,
                        help    = 'Enable debug mode',
                        )

    parser.add_argument('--trace',
                        action  = 'append',
                        default = [],
                        help    = 'Enable python debugging to trace a named resource.',
                    )

    parser.add_argument('--usage',
                        action  = 'store_true',
                        default = False,
                        help    = 'Show usage examples',
                        )
    
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')


    namespace = parser.parse_args()

    # --------------------------------------------------------------
    # [TODO] update --usage to accept a value, display context help.
    # --------------------------------------------------------------
    if namespace.usage:
        main_help.usage()

    return

# [EOF]
                 
