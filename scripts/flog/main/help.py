# -*- python -*-
## -----------------------------------------------------------------------
## -----------------------------------------------------------------------

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
