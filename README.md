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
  Reference: [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)

* `voltctl` and `kubectl` must be properly configured on your system
  prior to any test executions.  The `kind-voltha` environment will install
  and configure these tools for you; see below.

Directory is structured as follows:

```
├── tests
  └── functional/       // feature/functionality tests that should be implemented as new features get developed
└── libraries           // shared test keywords (functions) across various test suites
└── variables           // shared variables across various test suites
```

## Setting up a test environment

An easy way to bring up VOLTHA + BBSim for testing is by using
[kind-voltha](https://github.com/ciena/kind-voltha).  To set
up a minimal environment, first install [Docker](https://docs.docker.com/install/).

> NOTE: Please make sure you are able to run the docker command (your user is
> in the `docker` group)

If you don't have a Kubernetes cluster, please use the following command to
set up the cluster provided by [kind-voltha](https://github.com/ciena/kind-voltha)
and install required tools.

```bash
git clone https://github.com/ciena/kind-voltha
cd kind-voltha
TYPE=minimal WITH_RADIUS=y WITH_BBSIM=y CONFIG_SADIS=y WITH_SIM_ADAPTERS=n ./voltha up
source minimal-env.sh
```

If you prefer to use your own Kubernetes cluster, please read the document
[kind-voltha configuration
options](https://github.com/ciena/kind-voltha#voltha-up-configuration-options)
first to see how to configure the `kind-voltha` installation behavior.

* Recommended software versions

Helm: v2.14.3
Kubernetes: v1.15.5
KIND: v0.5.1

You can skip the installation of Kubernetes cluster and Helm by setting
environment variables.  For example, run the following command to install
VOLTHA only on an existing cluster.

```bash
git clone https://github.com/ciena/kind-voltha
cd kind-voltha
TYPE=minimal WITH_RADIUS=y WITH_BBSIM=y CONFIG_SADIS=y WITH_SIM_ADAPTERS=n DEPLOY_K8S=n INSTALL_KUBECTL=n INSTALL_HELM=n ./voltha up
source minimal-env.sh
```

The Helm values file `kind-voltha/minimal-values.yaml` determines which images will be deployed on the
Kubernetes cluster.   The default is `master` images from [VOLTHA's Docker
Hub repository](https://hub.docker.com/u/voltha/).  You can modify this file as needed, for
example to deploy released images or private test images.

### DT Workflow
If you want to install voltha for the DT Workflow, add `WITH_RADIUS=n WITH_EAPOL=n WITH_DHCP=n WITH_IGMP=n CONFIG_SADIS=n` flags in the `./voltha up` command above.

### Debug the kind-voltha installation

If you meet any issues when you set up the VOLTHA testing environment by
running `./voltha up`, you can see the installation logs from the file `kind-voltha/install-minimal.log`.

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

## Test variables

The `make sanity-single-kind` target is a shortcut that specifies a number of variables
used by the tests:

* ROBOT_FILE: The test suite file in `tests/functional` that will be invoked by `robot`.

* ROBOT_MISC_ARGS: Robot arguments passed directly to `robot`, for example to specify which test
cases to run.  If you are running in a non-standard environment (e.g., not created by `kind-voltha`)
you may need to override some default variable settings for your environment.
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
You can install it manually by following these steps below.

```bash
git clone https://github.com/ciena/kind-voltha.git
cd kind-voltha/
EXTRA_HELM_FLAGS='-f <PATH_TO_YOUR_K8S_CONFIG_FILE>' WITH_RADIUS=yes WITH_TP=yes DEPLOY_K8S=no INSTALL_KUBECTL=no INSTALL_HELM=no ./voltha up
```

Note: replace `PATH_TO_YOUR_K8S_CONFIG_FILE` with your Kubernetes configuration
file. To create one please check this
[example](https://github.com/opencord/pod-configs/blob/master/kubernetes-configs/voltha/flex-ocp-cord.yml).
For more information on various environment variables with `./voltha up` please
check the link
[here](https://github.com/ciena/kind-voltha/blob/master/README.md)

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
make voltha-test ROBOT_FILE=Voltha_PODTests.robot ROBOT_CONFIG_FILE=<PATH_TO_YOUR_POD_CONFIGURATION_FILE>
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

Most additions should be done by adding keywords to the libraries, then calling
these keywords from the tests.  Consult a [guide on how to write good Robot
framework
tests](https://github.com/robotframework/HowToWriteGoodTestCases/blob/master/HowToWriteGoodTestCases.rst).

When writing new functions, make sure there is proper documentation for it.
Also, follow a good naming convention for any new functions.  There are also
many keywords/functions available as part of the SEBA test framework which can
be found
[here](https://github.com/opencord/cord-tester/tree/master/src/test/cord-api/Framework)

Tests should be written in RobotFramework as they need to be integrated with
Jenkins test jobs.  Libraries can be written in python or RobotFramework.

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
  documentation](https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#dividing-test-data-to-several-rows)
  for more information.

* If it's an issue with a long shell invocation that uses a pipeline to filter
  output, try to see if you could use built-in Robot functionality for
  [string](https://robotframework.org/robotframework/latest/libraries/String.html)
  or
  [JSON](https://github.com/robotframework-thailand/robotframework-jsonlibrary)
  manipulation, rather than using shell tools like `sed`, `awk`, or `jq`.

* If you absolutely must use a long shell command, it can be stored in a string
  that is split over multiple lines with the
  [Catenate](https://robotframework.org/robotframework/latest/libraries/BuiltIn.html#Catenate)
  Keyword before it's run.
