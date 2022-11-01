# repo:voltha-system-tests

flog.py
-------
This script will be used as a central resource for identifying tests to run
when sources are changed.  Invoke with arguments and a list of testing
resources or jenkins jobs to run will be returned.

Unit tests are included for posterity: make check.

Consider the code alpha quality and highly subject to change.  Initial use
is inteded for interactive use, over time results will evolve to return
a list of directories and test suites passed to jenkins for consumption
or better yet logic able to checkout and invoke (~bbsim) tests locally.

Yes hardcoded jenkins URLs in the meta directory are gross but their
presence will be short lived.

mem_consumption.py
------------------

sizing.py
---------

which_deployment_owns_device.sh
-------------------------------
