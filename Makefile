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
             --configure TooManyTestSteps:30 -e TooManyTestSteps \
             --configure TooManyTestCases:50 -e TooManyTestCases \
             --configure TooFewTestSteps:1 \
             --configure TooFewKeywordSteps:1 \
             --configure FileTooLong:600 -e FileTooLong \
             -e TrailingWhitespace

PYTHON_FILES := $(wildcard libraries/*.py)
ROBOT_FILES  := $(shell find . -name *.robot -print)
YAML_FILES   := $(shell find ./tests -type f \( -name *.yaml -o -name *.yml \) -print)
JSON_FILES   := $(shell find ./tests -name *.json -print)

# Robot config
ROBOT_SANITY_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_DT_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-dt.yaml
ROBOT_FAIL_SINGLE_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_MULT_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind-2x2.yaml
ROBOT_SCALE_SINGLE_PON_FILE     ?= $(ROOT_DIR)/tests/data/bbsim-kind-16.yaml
ROBOT_SCALE_MULT_PON_FILE       ?= $(ROOT_DIR)/tests/data/bbsim-kind-8x2.yaml
ROBOT_DEBUG_LOG_OPT             ?=
ROBOT_MISC_ARGS                 ?=

# for backwards compatibility
sanity-kind: sanity-single-kind

# target to invoke DT Workflow Sanity
sanity-kind-dt: ROBOT_MISC_ARGS += -i sanityDt $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
sanity-kind-dt: ROBOT_FILE := Voltha_DT_PODTests.robot
sanity-kind-dt: voltha-dt-test

functional-single-kind: ROBOT_MISC_ARGS += -i sanity -i functional $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
functional-single-kind: bbsim-kind

# target to invoke DT Workflow Functional scenarios
functional-single-kind-dt: ROBOT_MISC_ARGS += -i sanityDt -i functionalDt $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
functional-single-kind-dt: ROBOT_FILE := Voltha_DT_PODTests.robot
functional-single-kind-dt: voltha-dt-test

sanity-single-kind: ROBOT_MISC_ARGS += -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
sanity-single-kind: bbsim-kind

rwcore-restart-single-kind: ROBOT_MISC_ARGS += -X -i bbsimANDrwcore-restart $(ROBOT_DEBUG_LOG_OPT)
rwcore-restart-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_FAIL_SINGLE_PON_FILE)
rwcore-restart-single-kind: ROBOT_FILE := Voltha_PODTests.robot
rwcore-restart-single-kind: voltha-test

single-kind: ROBOT_MISC_ARGS += -X -i $(TEST_TAGS) $(ROBOT_DEBUG_LOG_OPT)
single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
single-kind: ROBOT_FILE := Voltha_PODTests.robot
single-kind: voltha-test

sanity-multi-kind: ROBOT_MISC_ARGS += -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
sanity-multi-kind: bbsim-kind

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
bbsim-alarms-kind: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_SINGLE_PON_FILE)
bbsim-alarms-kind: voltctl-docker-image-build voltctl-docker-image-install-kind voltha-test

voltha-test: ROBOT_MISC_ARGS += -e notready

voltha-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/functional ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-dt-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/dt-workflow ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

# self-test, lint, and setup targets

# virtualenv for the robot tools
vst_venv:
	virtualenv -p python3 $@ ;\
	source ./$@/bin/activate ;\
	pip install -r requirements.txt

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
