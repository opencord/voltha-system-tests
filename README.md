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
    * `voltctl` and `kubectl` should be configured to your system under test
      prior to any test executions

Directory is structured as follows:

```
├── tests
  └── sanity/           // basic tests that should always pass. Will be used as gating-patchsets
  └── functional/       // feature/functionality tests that should be implemented as new features get developed
└── libraries           // shared test keywords (functions) across various test suites
└── variables           // shared variables across various test suites
```

## Running the tests

1. Download `voltha-system-tests`
  * `git clone https://gerrit.opencord.org/voltha-system-tests`

2. Create test virtual-environment
  * `cd voltha-system-tests/`
  * `source setup_venv.sh`

3. Running Test-Suites
  * Navigate to desired test suite location
  * `robot --exclude notready sanity.robot`

This test execution will generate three report files (`output.xml`,
`report.html`, `log.html`). View the `report.html` page to analyze the results.

## Adding to the tests

Ideally most additions should be done by adding keywords to the libraries, then
called from the tests.

Make sure that `make lint` passes, which runs
[robotframework-lint](https://github.com/boakley/robotframework-lint) on any
new code that is created.

## WIP:

*  Containerizing test environment so these tests can be run independent of the system.

