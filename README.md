#System-Tests

Automated test-suites to validate the stability/functionality of VOLTHA. Tests that reside in here should be written in Robot Framework and Python.

Intended use includes:

* Sanity testing
* Regression testing
* Acceptance testing
* Functional testing
* Scale Testing using BBSIM
* Failure/Scenario testing

##Prerequisites
* Python Virtual-Env
* `voltctl` - a command line tool to access VOLTHA. Reference - [voltctl](https://github.com/ciena/voltctl)
* `kubectl` - a command line tool to access your Kubernetes Clusers. Reference - [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)
    * `voltctl` and `kubectl` should be configured to your system under test prior to any test executions

Directory Structures are as followed:
```
├── tests
  └── sanity/           // basic tests that should always pass. Will be used as gating-patchsets
  └── functional/       // feature/functionality tests that should be implemented as new features get developed
└── libraries           // shared test keywords (functions) across various test suites
└── variables           // shared variables across various test suites
```


##Getting Started
1. Download `voltha-system-tests`
    * `git clone https://gerrit.opencord.org/voltha-system-tests`

2. Create test virtual-environment
    * `cd voltha-system-tests/`
    * `source setup_venv.sh`
3. Running Test-Suites
    * Navigate to desired test suite location
    * `robot --exclude notready sanity.robot`

This test execution will generate three report files (`output.xml`, `report.html`, `log.html`). View the `report.html` page to analyze the results. 

## WIP:
*  Containerizing test environment so these tests can be run independent of the system