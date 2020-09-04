# Copyright 2017-present Open Networking Foundation
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

# use bash for pushd/popd, and to fail quickly. virtualenv's activate
# has undefined variables, so no -u
SHELL     := bash -e -o pipefail

ROOT_DIR  := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Configuration and lists of files for linting/testing
VERSION   ?= $(shell cat ./VERSION)
LINT_ARGS ?= --verbose --configure LineTooLong:120 -e LineTooLong \
             --configure TooManyTestSteps:50 -e TooManyTestSteps \
             --configure TooManyTestCases:50 -e TooManyTestCases \
             --configure TooFewTestSteps:1 \
             --configure TooFewKeywordSteps:1 \
             --configure FileTooLong:1100 -e FileTooLong \
             -e TrailingWhitespace

PYTHON_FILES := $(wildcard libraries/*.py)
ROBOT_FILES  := $(shell find . -name *.robot -print)
YAML_FILES   := $(shell find ./tests -type f \( -name *.yaml -o -name *.yml \) -print)
JSON_FILES   := $(shell find ./tests -name *.json -print)

# Robot config
ROBOT_SANITY_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_DT_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-dt.yaml
ROBOT_SANITY_MULTIPLE_OLT_FILE    ?= $(ROOT_DIR)/tests/data/multiple-bbsim-kind.yaml
ROBOT_FAIL_SINGLE_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_MULT_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind-2x2.yaml
ROBOT_SCALE_SINGLE_PON_FILE     ?= $(ROOT_DIR)/tests/data/bbsim-kind-16.yaml
ROBOT_SCALE_MULT_PON_FILE       ?= $(ROOT_DIR)/tests/data/bbsim-kind-8x2.yaml
ROBOT_SCALE_MULT_ONU_FILE       ?= $(ROOT_DIR)/tests/data/bbsim-kind-8x8.yaml
ROBOT_DEBUG_LOG_OPT             ?=
ROBOT_MISC_ARGS                 ?=
ROBOT_SANITY_TT_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-tt.yaml

# for backwards compatibility
sanity-kind: sanity-single-kind

# for scale pipeline
voltha-scale: ROBOT_MISC_ARGS += -i activation $(ROBOT_DEBUG_LOG_OPT)
voltha-scale: voltha-scale-test

# target to invoke DT Workflow Sanity
sanity-kind-dt: ROBOT_MISC_ARGS += -i sanityDt $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
sanity-kind-dt: ROBOT_FILE := Voltha_DT_PODTests.robot
sanity-kind-dt: voltha-dt-test

functional-single-kind: ROBOT_MISC_ARGS += -i sanityORfunctional -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
functional-single-kind: bbsim-kind

# target to invoke DT Workflow Functional scenarios
functional-single-kind-dt: ROBOT_MISC_ARGS += -i sanityDtORfunctionalDt -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
functional-single-kind-dt: ROBOT_FILE := Voltha_DT_PODTests.robot
functional-single-kind-dt: voltha-dt-test

# target to invoke TT Workflow Sanity
sanity-kind-tt: ROBOT_MISC_ARGS += -i sanityTT $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
sanity-kind-tt: ROBOT_FILE := Voltha_TT_PODTests.robot
sanity-kind-tt: voltha-tt-test

# target to invoke TT Workflow Functional scenarios
functional-single-kind-tt: ROBOT_MISC_ARGS += -i sanityTTORfunctional -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
functional-single-kind-tt: ROBOT_FILE := Voltha_TT_PODTests.robot
functional-single-kind-tt: voltha-tt-test

# target to invoke multiple OLTs Functional scenarios
functional-multi-olt: ROBOT_MISC_ARGS += -i sanityMultiOLT $(ROBOT_DEBUG_LOG_OPT)
functional-multi-olt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
functional-multi-olt: ROBOT_FILE := Voltha_multipleOLTTests.robot
functional-multi-olt: voltha-test

# target to invoke openonu go adapter
openonu-go-adapter-test: ROBOT_MISC_ARGS += -v state2test:6 -v testmode:SingleStateTime -v timeout:180s
openonu-go-adapter-test: ROBOT_MISC_ARGS += -v logging:True -i onutest $(ROBOT_DEBUG_LOG_OPT)
openonu-go-adapter-test: ROBOT_MISC_ARGS += -X
openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUStateTests.robot
openonu-go-adapter-test: openonu-go-adapter-statetest

# target to invoke test with openonu go adapter applying 1T4GEM tech-profile at single ONU
1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v state2test:6 -v testmode:SingleStateTime -v timeout:180s
1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v techprofile:1T4GEM -v logging:True
1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -i onutest $(ROBOT_DEBUG_LOG_OPT)
1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -X
1t4gem-openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
1t4gem-openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUStateTests.robot
1t4gem-openonu-go-adapter-test: openonu-go-adapter-statetest

# target to invoke test with openonu go adapter applying 1T8GEM tech-profile at single ONU
1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v state2test:6 -v testmode:SingleStateTime -v timeout:180s
1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v techprofile:1T8GEM -v logging:True
1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -i onutest $(ROBOT_DEBUG_LOG_OPT)
1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -X
1t8gem-openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
1t8gem-openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUStateTests.robot
1t8gem-openonu-go-adapter-test: openonu-go-adapter-statetest

# target to invoke multiple openonu go adapter
multi-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v state2test:6 -v testmode:SingleStateTime -v timeout:180s
multi-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v logging:True -i onutest $(ROBOT_DEBUG_LOG_OPT)
multi-openonu-go-adapter-test: ROBOT_MISC_ARGS += -X
multi-openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_MULT_ONU_FILE)
multi-openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUStateTests.robot
multi-openonu-go-adapter-test: openonu-go-adapter-statetest

# target to invoke test with openonu go adapter applying 1T4GEM tech-profile at multiple ONU
multi-1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v state2test:6 -v testmode:SingleStateTime -v timeout:180s
multi-1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v techprofile:1T4GEM -v logging:True
multi-1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -i onutest $(ROBOT_DEBUG_LOG_OPT)
multi-1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -X
multi-1t4gem-openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_MULT_ONU_FILE)
multi-1t4gem-openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUStateTests.robot
multi-1t4gem-openonu-go-adapter-test: openonu-go-adapter-statetest

# target to invoke test with openonu go adapter applying 1T8GEM tech-profile at multiple ONU
multi-1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v state2test:6 -v testmode:SingleStateTime -v timeout:180s
multi-1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v techprofile:1T8GEM -v logging:True
multi-1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -i onutest $(ROBOT_DEBUG_LOG_OPT)
multi-1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -X
multi-1t8gem-openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_MULT_ONU_FILE)
multi-1t8gem-openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUStateTests.robot
multi-1t8gem-openonu-go-adapter-test: openonu-go-adapter-statetest

sanity-single-kind: ROBOT_MISC_ARGS += -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
sanity-single-kind: bbsim-kind

rwcore-restart-single-kind: ROBOT_MISC_ARGS += -X -i functionalANDrwcore-restart $(ROBOT_DEBUG_LOG_OPT)
rwcore-restart-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_FAIL_SINGLE_PON_FILE)
rwcore-restart-single-kind: ROBOT_FILE := Voltha_FailureScenarios.robot
rwcore-restart-single-kind: voltha-test

single-kind: ROBOT_MISC_ARGS += -X -i $(TEST_TAGS) $(ROBOT_DEBUG_LOG_OPT)
single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
single-kind: ROBOT_FILE := Voltha_PODTests.robot
single-kind: voltha-test

sanity-multi-kind: ROBOT_MISC_ARGS += -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
sanity-multi-kind: bbsim-kind

functional-multi-kind: ROBOT_MISC_ARGS += -i sanityORfunctional $(ROBOT_DEBUG_LOG_OPT)
functional-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
functional-multi-kind: bbsim-kind

bbsim-kind: ROBOT_MISC_ARGS += -X
bbsim-kind: ROBOT_FILE := Voltha_PODTests.robot
bbsim-kind: voltha-test

scale-single-kind: ROBOT_MISC_ARGS += -i active $(ROBOT_DEBUG_LOG_OPT)
scale-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_SINGLE_PON_FILE)
scale-single-kind: bbsim-scale-kind

scale-multi-kind: ROBOT_MISC_ARGS += -i active $(ROBOT_DEBUG_LOG_OPT)
scale-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_MULT_PON_FILE)
scale-multi-kind: bbsim-scale-kind

bbsim-scale-kind: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-scale-kind: ROBOT_FILE := Voltha_ScaleFunctionalTests.robot
bbsim-scale-kind: voltha-test

#Only supported in full mode
system-scale-test: ROBOT_FILE := K8S_SystemTest.robot
system-scale-test: ROBOT_MISC_ARGS += -X -i functional $(ROBOT_DEBUG_LOG_OPT)
system-scale-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
system-scale-test: voltha-test

failure-test: ROBOT_MISC_ARGS += -X -i FailureTest $(ROBOT_DEBUG_LOG_OPT)
failure-test: ROBOT_FILE := K8S_SystemTest.robot
failure-test: ROBOT_CONFIG_FILE := $(ROBOT_FAIL_SINGLE_PON_FILE)
failure-test: voltha-test

bbsim-alarms-kind: ROBOT_MISC_ARGS += -X -i active
bbsim-alarms-kind: ROBOT_FILE := Voltha_AlarmTests.robot
bbsim-alarms-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
bbsim-alarms-kind: voltctl-docker-image-build voltctl-docker-image-install-kind voltha-test

bbsim-errorscenarios: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-errorscenarios: ROBOT_FILE := Voltha_ErrorScenarios.robot
bbsim-errorscenarios: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
bbsim-errorscenarios: voltha-test

bbsim-errorscenarios-dt: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-errorscenarios-dt: ROBOT_FILE := Voltha_ErrorScenarios.robot
bbsim-errorscenarios-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
bbsim-errorscenarios-dt: voltha-test

bbsim-failurescenarios: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e PhysicalOLTReboot
bbsim-failurescenarios: ROBOT_FILE := Voltha_FailureScenarios.robot
bbsim-failurescenarios: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
bbsim-failurescenarios: voltha-test

bbsim-failurescenarios-dt: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitchOnuRebootDt -e PhysicalOltRebootDt
bbsim-failurescenarios-dt: ROBOT_FILE := Voltha_DT_FailureScenarios.robot
bbsim-failurescenarios-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
bbsim-failurescenarios-dt: voltha-dt-test

voltha-test: ROBOT_MISC_ARGS += -e notready

voltha-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/functional ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-dt-test: ROBOT_MISC_ARGS += -e notready

voltha-dt-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/dt-workflow ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-tt-test: ROBOT_MISC_ARGS += -e notready

voltha-tt-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/tt-workflow ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-scale-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/scale ;\
	robot $(ROBOT_MISC_ARGS) Voltha_Scale_Tests.robot

openonu-go-adapter-statetest: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/openonu-go-adapter ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)


# self-test, lint, and setup targets

# virtualenv for the robot tools
# VOL-2724 Invoke pip via python3 to avoid pathname too long on QA jobs
vst_venv:
	virtualenv -p python3 $@ ;\
	source ./$@/bin/activate ;\
	python -m pip install -r requirements.txt

test: lint

lint: lint-robot lint-python lint-yaml lint-json

lint-robot: vst_venv
	source ./$</bin/activate ; set -u ;\
	rflint $(LINT_ARGS) $(ROBOT_FILES)

# check deps for format and python3 cleanliness
lint-python: vst_venv
	source ./$</bin/activate ; set -u ;\
	pylint --py3k $(PYTHON_FILES) ;\
	flake8 --max-line-length=99 --count $(PYTHON_FILES)

lint-yaml: vst_venv
	source ./$</bin/activate ; set -u ;\
  yamllint -s $(YAML_FILES)

lint-json: vst_venv
	source ./$</bin/activate ; set -u ;\
	for jsonfile in $(JSON_FILES); do \
		echo "Validating json file: $$jsonfile" ;\
		python -m json.tool $$jsonfile > /dev/null ;\
	done

# tidy target will be more useful once issue with removing leading comments
# is resolved: https://github.com/robotframework/robotframework/issues/3263
tidy-robot: vst_venv
	source ./$</bin/activate ; set -u ;\
	python -m robot.tidy --inplace $(ROBOT_FILES);

# Install the 'kail' tool if needed: https://github.com/boz/kail
KAIL_PATH ?= /usr/local/bin
$(KAIL_PATH)/kail:
	bash <( curl -sfL https://raw.githubusercontent.com/boz/kail/master/godownloader.sh) -b /tmp
	mv /tmp/kail $(KAIL_PATH)

## Variables for gendocs
TEST_SOURCE := $(wildcard tests/*/*.robot)
TEST_BASENAME := $(basename $(TEST_SOURCE))
TEST_DIRS := $(dir $(TEST_SOURCE))

LIB_SOURCE := $(wildcard libraries/*.robot)
LIB_BASENAME := $(basename $(LIB_SOURCE))
LIB_DIRS := $(dir $(LIB_SOURCE))

.PHONY: gendocs lint test
# In future explore use of --docformat REST - integration w/Sphinx?
gendocs: vst_venv
	source ./$</bin/activate ; set -u ;\
	mkdir -p $@ ;\
	for dir in ${LIB_DIRS}; do mkdir -p $@/$$dir; done;\
	for dir in ${LIB_BASENAME}; do\
		python -m robot.libdoc --format HTML $$dir.robot $@/$$dir.html ;\
	done ;\
	for dir in ${TEST_DIRS}; do mkdir -p $@/$$dir; done;\
	for dir in ${TEST_BASENAME}; do\
		python -m robot.testdoc $$dir.robot $@/$$dir.html ;\
	done

clean:
	find . -name output.xml -print

clean-all: clean
	rm -rf vst_venv gendocs

voltctl-docker-image-build:
	cd docker && docker build -t opencord/voltctl:local -f Dockerfile.voltctl .

voltctl-docker-image-install-kind:
	@if [ "`kind get clusters | grep voltha`" = '' ]; then echo "no voltha cluster found" && exit 1; fi
	kind load docker-image --name `kind get clusters | grep voltha` opencord/voltctl:local
