# VOLTHA System Tests

Automated test-suites to validate the stability/functionality of VOLTHA. Tests
that reside in here should be written in Robot Framework and Python.

Intended use includes:

* Functional testing
* Integration and Acceptance testing
* Sanity and Regression testing
* Scale Testing using BBSIM
* Failure scenario testing

## Prerequisites

* Python [virtualenv](https://virtualenv.pypa.io/en/latest/)

* `voltctl` - a command line tool to access VOLTHA. Reference -
  [voltctl](https://github.com/opencord/voltctl)

* `kubectl` - a command line tool to access your Kubernetes Clusers. Reference
  - [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)

* `voltctl` and `kubectl` must be properly configured on your system
  prior to any test executions.  The `kind-voltha` environment will install
  and configure these tools for you; see below.

Directory is structured as follows:

```
├── tests
  └── sanity/           // basic tests that should always pass. Will be used as gating-patchsets
  └── functional/       // feature/functionality tests that should be implemented as new features get developed
└── libraries           // shared test keywords (functions) across various test suites
└── variables           // shared variables across various test suites
```

## Setting up a test environment

An easy way to bring up VOLTHA + BBSim for testing is by using
[kind-voltha](https://github.com/ciena/kind-voltha).  To set
up a minimal environment, first install [Docker](https://docs.docker.com/install/)
and [the Go programming language](https://golang.org/doc/install).
Then run the following commands:

```bash
git clone https://github.com/ciena/kind-voltha
cd kind-voltha
EXTRA_HELM_FLAGS="--set defaults.image_tag=voltha-2.1” TYPE=minimal WITH_RADIUS=y WITH_BBSIM=y INSTALL_ONOS_APPS=y CONFIG_SADIS=y ./voltha up
source minimal-env.sh
```

The `defaults.image_tag` value above is used to specify which VOLTHA
branch images to pull from Docker Hub.

## Running the sanity tests

Assuming that you have brought up VOLTHA as described above,
to run the the sanity tests:

```bash
git clone https://github.com/opencord/voltha-system-tests
make -C voltha-system-tests sanity-kind
```

This test execution will generate three report files in
`voltha-system-tests/tests/sanity` (`output.xml`,
`report.html`, `log.html`). View the `report.html` page in a browser
to analyze the results.

## Test variables

The `make sanity-kind` target is equivalent to the following:
```
ROBOT_PORT_ARGS="-v ONOS_REST_PORT:8181 -v ONOS_SSH_PORT:8101" \
ROBOT_TEST_ARGS="--exclude notready --critical sanity" \
ROBOT_MISC_ARGS="-v num_onus:1" \
make sanity
```
If you are running the tests in another environment, you can run `make sanity`
with the arguments appropriate for your environment.  Look at
[variables.robot](variables/variables.robot) for a list of variables that
you may need to override.

# Running Tests on Physical POD

Assuming that a POD is available with all the required hardware and connections, we can
deploy the POD by following the procedure in this section below.

## Deploying POD
 
Deploying POD can be either be manual or automated using Jenkins job.

You can install it manually by following these steps below.

```              
git clone https://github.com/ciena/kind-voltha.git
cd kind-voltha/
EXTRA_HELM_FLAGS='-f $WORKSPACE/${configBaseDir}/${configKubernetesDir}/voltha/${configFileName}.yml' WITH_RADIUS=y WITH_TP=yes DEPLOY_K8S=no INSTALL_KUBECTL=no INSTALL_HELM=no ONOS_TAG=voltha-2.1 ./voltha up
```
For more information on various environment variables available with `./voltha up` please 
check the link [here](https://github.com/ciena/kind-voltha/blob/master/README.md)

If you want to deploy it using Jenkins, follow the steps below

* Clone `pod-configs` repo `git clone https://gerrit.opencord.org/pod-configs`
* Create a deployment file which contains the details of the hardware that are needed for 
  configuring the POD. Create this file with the <name of your POD>.yaml under 
  `pod-configs/deployment-configs/` directory. [Example Deployment File](https://github.com/opencord/pod-configs/blob/master/deployment-configs/flex-ocp-cord.yaml)
* Create Input/Configuration files needed for configuring the POD after installation in
  `pod-configs/tosca-configs/voltha` folder. Again config files are named after the pod.
  [<pod name>-onos-netcfg-switch.json](https://github.com/opencord/pod-configs/blob/master/tosca-configs/voltha/flex-ocp-cord-onos-netcfg-switch.json).
  This file contains the netcfg related to the fabric switch. If your POD does not have a fabric switch,
  please ignore this step.
* Technology profiles and sadis configurations are also pushed as part of the deployment job.
  These are placed under `voltha-system-test/tests/data`.  The files are named after the 
  name of the POD [<POD name>-sadis.json](https://github.com/opencord/voltha-system-tests/blob/master/tests/data/flex-ocp-cord-sadis.json),
  [<POD_Name>.multipleGem.json](https://github.com/opencord/voltha-system-tests/blob/master/tests/data/flex-ocp-cord-multipleGem.json)
* Jenkins groovy script for deploying the POD is in `voltha-system-tests/` repo.  `Jenkins-voltha-build` 
  is the name of the file.  Please check the various stages and remove stages that might not be necessary
  for your POD.  Example: You will not need `Configure Switch in ONOS` section if your POD does not contain a switch.
* Once all the required files are ready,  and if you plan to deploy the POD using jenkins. A jenkins job 
  can be built using an existing template defined in `ci-management` repo. Deployment job templates can be 
  found in `ci-management/jjb/cord-test/night-build-pipeline.yaml` file.

# Functional Testcases

All functional test cases are placed under `functional` folder.
`Voltha_PODTests.robot` consists of testcases that can be run on a physical POD.
The same test script `Voltha_PODTests.robot` can be run on any POD. Instead of hardcoding
the POD specific variables in the test script, it relies on a separate configuration file which
describes the POD setup. File contains details like the ONUs, OLT, nodes etc. To create a configuration file for your
POD please take a look at this [example](https://github.com/opencord/pod-configs/blob/master/deployment-configs/flex-ocp-cord.yaml)

Input data are stored in the `data` folder. Few examples of input data could be, test specific sadis configurations,
tech profiles etc. Please give appropriate file names to the input files.

To trigger tests on the physical POD
```
cd voltha-system-tests/tests/functional
robot -V <PATH_TO_YOUR_POD_CONFIGURATION_FILE> ATT_Test001.robot
```
Note: PATH_TO_YOUR_POD_CONFIGURATION_FILE should point to the yaml file that describes your POD setup.

Scenarios in each test suite can be associated with a `Tag`, using which a particular scenario can be 
invoked during test execution.
As an example to execute only one testcase from the test suite you can do something like here
```
cd voltha-system-tests/tests/functional
robot -i test1 -V <PATH_TO_YOUR_POD_CONFIGURATION_FILE> ATT_Test001.robot
```
## Adding to the tests

Most additions should be done by adding keywords to the libraries, then
calling these keywords from the tests.  Consult a
[guide on how to write good Robot framework tests](https://github.com/robotframework/HowToWriteGoodTestCases/blob/master/HowToWriteGoodTestCases.rst).
When writing new functions, make sure there is proper documentation for it.  Also, follow a
good naming convention for any new functions.
There are also many keywords/functions available as part of the SEBA test framework which
can be found [here](https://github.com/opencord/cord-tester/tree/master/src/test/cord-api/Framework)

Tests should be written in RobotFramework as they need to be integrated with Jenkins test jobs.
Libraries can be written in python or RobotFramework.

Make sure that `make lint` passes, which runs
[robotframework-lint](https://github.com/boakley/robotframework-lint) on any
new code that is created.

## WIP:

*  Containerizing test environment so these tests can be run independent of the system.

