# VOLTHA System Tests

Automated test-suites to validate the stability/functionality of VOLTHA. Tests
that reside in here should be written in Robot Framework and Python.

Intended use includes:

* Functional testing
* Integration and Acceptance testing
* Sanity and Regression testing
* Scale Testing using BBSIM
* Failure scenario testing

Learn more about VOLTHA System Test in [Test Automation
Brigade](https://drive.google.com/drive/u/1/folders/1BzyBoEURG2pVfyYBXnWUI30uy0FfdBHA).

## Prerequisites

* Python 3.5 or later and [virtualenv](https://virtualenv.pypa.io/en/latest/)

* `voltctl` - a command line tool to access VOLTHA. Reference -
  [voltctl](https://github.com/opencord/voltctl)

* `kubectl` - a command line tool to access your Kubernetes Clusters.
  Reference - [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)

* `voltctl` and `kubectl` must be properly configured on your system
  prior to any test executions.

Directory is structured as follows:

```
├── tests
  └── functional/       // feature/functionality tests that should be implemented as new features get developed
└── libraries           // shared test keywords (functions) across various test suites
└── variables           // shared variables across various test suites
```

## Setting up a test environment

An easy way to bring up VOLTHA + BBSim for testing is by using the `helm-charts` as described in
[voltha-helm-charts README](https://github.com/opencord/voltha-helm-charts/blob/master/README.md). To set
up a minimal environment, first install [Docker](https://docs.docker.com/install/).

> NOTE: Please make sure you are able to run the docker command (your user is
> in the `docker` group)

Then you can follow all the instructions in the [voltha-helm-charts README](https://github.com/opencord/voltha-helm-charts/blob/master/README.md).

## Running the sanity tests

Assuming that you have brought up VOLTHA as described above, you can run a simple E2E "sanity"
test as follows:

```bash
git clone https://github.com/opencord/voltha-system-tests
make -C voltha-system-tests sanity-single-kind
```

The tests generate three report files in
`voltha-system-tests/tests/functional` (`output.xml`, `report.html`, `log.html`).
View the `report.html` page in a browser to analyze the results.
If you're running on a remote system, you can start a web server with `python3
-m http.server`.

### DT Workflow
To run the sanity tests for the DT Workflow, use `sanity-kind-dt` as the make target.
```bash
git clone https://github.com/opencord/voltha-system-tests
make -C voltha-system-tests sanity-kind-dt
```

The tests generate three report files in
`voltha-system-tests/tests/dt-workflow/` (`output.xml`, `report.html`, `log.html`).
View the `report.html` page in a browser to analyze the results.
If you're running on a remote system, you can start a web server with `python3
-m http.server`.


## Test variables

The `make sanity-single-kind` target is a shortcut that specifies a number of variables
used by the tests:

* ROBOT_FILE: The test suite file in `tests/functional` that will be invoked by `robot`.

* ROBOT_MISC_ARGS: Robot arguments passed directly to `robot`, for example to specify which test
cases to run. For some environments you may need to override some default variable settings for your environment.
See [variables.robot](https://github.com/opencord/voltha-system-tests/blob/master/variables/variables.robot)
for the list of defaults.

* ROBOT_CONFIG_FILE: The YAML pod deployment file used to drive the test.  Examples are in the
`tests/data` directory.

## Running Tests on Physical POD

Assuming that a POD is available with all the required hardware and
connections, we can deploy the POD by following the procedure in this section
below.

### Deploying POD

Deploying POD can be either manual or automated using Jenkins job.
You can install it manually by following the steps in 
[voltha-helm-charts README](https://github.com/opencord/voltha-helm-charts/blob/master/README.md)

Note: please add `-f PATH_TO_YOUR_K8S_CONFIG_FILE` to your helm commands with your Kubernetes configuration
file. To create one please check this
[example](https://github.com/opencord/pod-configs/blob/master/kubernetes-configs/voltha/flex-ocp-cord.yml).

### Dataplane test prerequisites

The dataplane tests evaluate whether bandwidth and tech profiles are working as expected.
These tests will only run on a physical pod.  In order to run them it is required to manually install
some additional software on the POD hosts that emulate the RG and BNG.

On the RG hosts:
* Install `iperf3` version 3.7, available here: https://software.es.net/iperf/
* Install `jq`: `sudo apt install jq`
* Install `mausezahn`: `sudo apt install netsniff-ng`
* Ensure that the following commands can be run as `sudo` with no password: `tcpdump`, `mausezahn`, `pkill`

On the BNG host:
* Install `iperf3` version 3.7, available here: https://software.es.net/iperf/
* Run `iperf3` in server mode in the background: `iperf3 --server -D`
* Install `jq`: `sudo apt install jq`
* Install `mausezahn`: `sudo apt install netsniff-ng`
* Ensure that the following commands can be run as `sudo` with no password: `tcpdump`, `mausezahn`, `pkill`

In the POD's deployment config file, specify login information for the BNG host using the `noroot_ip`, `noroot_user`,
and `noroot_pass` options.  See the [Tucson pod's config](https://github.com/opencord/pod-configs/blob/master/deployment-configs/tucson-pod.yaml)
for an example.

## Functional Testcases

All functional test cases are placed under `functional` folder.

`Voltha_PODTests.robot` consists of functional testcases that can be run on a
physical POD.

Each robot testcase has a description in the `Documentation` section.

The same suite of tests can be run on any POD because parameters needed for the
test are written in .yaml file. Instead of hardcoding the POD specific
variables in the test case, tests rely on a separate configuration file which
describes the POD setup. This `.yaml` file contains details like the ONUs, OLT,
nodes etc.

To create a configuration file for your POD, check this
[example](https://github.com/opencord/pod-configs/blob/master/deployment-configs/flex-ocp-cord.yaml)

Input data are stored in the `data` folder. Few examples of input data could
be, test specific SADIS configurations, tech profiles etc. Please give
appropriate file names to the input files.

To trigger tests on the physical POD

```bash
git clone https://github.com/opencord/voltha-system-tests
cd voltha-system-tests
make voltha-test ROBOT_FILE="Voltha_PODTests.robot" ROBOT_CONFIG_FILE="<PATH_TO_YOUR_POD_CONFIGURATION_FILE>"
```

Note: `PATH_TO_YOUR_POD_CONFIGURATION_FILE` should point to the YAML file that
describes your POD setup.

Scenarios in each test suite can be associated with a `Tag`, using which a
particular scenario can be invoked during test execution.  As an example to
execute only one testcase with tag `test1` from the test suite you can run:

```bash
make voltha-test ROBOT_MISC_ARGS="-i test1" ROBOT_FILE="Voltha_PODTests.robot" ROBOT_CONFIG_FILE="<PATH_TO_YOUR_POD_CONFIGURATION_FILE>"
```

## Adding to the tests


Tests should be written in RobotFramework as they need to be integrated with
Jenkins test jobs.  Libraries can be written in python or RobotFramework.
Most additions should be done by adding keywords to the libraries, then calling
these keywords from the tests.  Consult a [guide on how to write good Robot
framework
tests](https://github.com/robotframework/HowToWriteGoodTestCases/blob/master/HowToWriteGoodTestCases.rst).

The [cord-robot](https://pypi.org/project/cord-robot/) package provides a number of useful
keywords for writing VOLTHA tests.  See [this link](https://github.com/opencord/cord-tester/tree/master/cord-robot)
for information on how to import the library into a Robot test suite.  The `cord-robot`
package version is specified in the `requirements.txt` file.  The package is automatically
installed into the Python virtualenv set up by the Makefile.

Make sure that `make lint` check passes, which runs
[robotframework-lint](https://github.com/boakley/robotframework-lint) on any
new code that is created. The goal of the linter is to ensure that code is well
formatted and structured, and that test suites are of a reasonable size.  Lint
can fail for a variety of reasons, usually related to formatting.

If you have trouble with the line length check, try the following:

* If you get a Line Length related problem, you can continue lines between
  keywords with the `...` operator - see the [robot
  documentation](https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#dividing-data-to-several-rows)
  for more information.

* If it's an issue with a long shell invocation that uses a pipeline to filter
  output, try to see if you could use built-in Robot functionality for
  [string](https://robotframework.org/robotframework/latest/libraries/String.html)
  or
  [JSON](https://github.com/robotframework-thailand/robotframework-jsonlibrary)
  manipulation, rather than using shell tools like `sed`, `awk`, or `jq`.

* If you absolutely must use a long shell command, it can be stored in a string
  that is split over multiple lines with the
  [Catenate](https://robotframework.org/robotframework/latest/libraries/BuiltIn.html)
  Keyword before it's run.
