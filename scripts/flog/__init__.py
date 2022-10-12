##-------------------##
##---]  IMPORTS  [---##
##-------------------##
import sys
from pathlib import Path

# pylint: disable=using-constant-test
if True:
    # artifical scope enables local var use
    parent = Path('..').resolve().as_posix()
    sys.path.insert(0, parent)

# [EOF]
