# -*- python -*-
## -----------------------------------------------------------------------
## Intent: This module contains general helper methods
## -----------------------------------------------------------------------

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
##---]  IMPORTS  [---##
##-------------------##
import sys
import pprint

## ---------------------------------------------------------------------------
## ---------------------------------------------------------------------------
def iam():
    """Return name of a called method."""

    func_name = sys._getframe(1).f_code.co_name # pylint: disable=protected-access
    iam       = "%s::%s" % (__name__, func_name)
    return iam

## -----------------------------------------------------------------------
## Intent: Display a message then exit with non-zero status.
##   This method cannot be intercepted by try/except
## -----------------------------------------------------------------------
def error(msg, exit_with=None, fatal=None):
    """Display a message then exit with non-zero status.

    :param msg: Error mesage to display.
    :type  msg: string

    :param exit_with: Shell exit status.
    :type  exit_with: int, optional (default=2)

    :param fatal: When true raise an exception.
    :type  fatal: bool (default=False)

    """

    if exit_with is None:
        exit_with = 2

    if fatal is None:
        fatal = false

    if msg:
        if fatal:
            raise Exception("ERROR: %s" % msg)
        else:
            print("")
            print("ERROR: %s" % msg)

    sys.exit(exit_with)

# EOF
