# -*- python -*-
# -----------------------------------------------------------------------
# Copyright 2022 Open Networking Foundation (ONF) and the ONF Contributors
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
##---]  IMPORTS  [---##
##-------------------##
import __main__
import os
import sys

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
def show_examples():
    '''Display examples of command usage'''

    cmd = os.path.basename(__main__.__file__)

    print('''
%% %s
  Run all tests (default)

%% %s --type regression
  Run only regression tests.

%% %s --type smoke
  Run a quick battery of tests.

%% %s --type suite --test unit --attr olt --attr onu
  Run module tests for olt and onu.

%% %s --type regression --attr gpon
  Run regression tests for gpon logic.
''' % (cmd, cmd, cmd, cmd, cmd))
#    print( (cmd) * 5) # syntax ?!?

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
def usage():
    """Display command arguments and usage

    :param err: Error to display due to invalid arg parsing.
    :type  err: String

    :param arg: --help* command line argument digested by argparse.py
    :type  arg: String

    :raises  ValueError

    ...versionadded: 1.1
    """

    cmd = os.path.basename(__main__.__file__)
    print("USAGE: %s" % cmd)
    show_examples()
    sys.exit(0)

# EOF
