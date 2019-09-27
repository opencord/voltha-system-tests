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
up a minimal environment, first [install Docker](https://docs.docker.com/install/)
and then run the following commands:

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

## Adding to the tests

Most additions should be done by adding keywords to the libraries, then
calling these keywords from the tests.  Consult a
[guide on how to write good Robot framework tests](https://github.com/robotframework/HowToWriteGoodTestCases/blob/master/HowToWriteGoodTestCases.rst).

Make sure that `make lint` passes, which runs
[robotframework-lint](https://github.com/boakley/robotframework-lint) on any
new code that is created.

## WIP:

*  Containerizing test environment so these tests can be run independent of the system.

