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
ROBOT_FAIL_SINGLE_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_MULT_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind-2x2.yaml
ROBOT_SCALE_SINGLE_PON_FILE     ?= $(ROOT_DIR)/tests/data/bbsim-kind-16.yaml
ROBOT_SCALE_MULT_PON_FILE       ?= $(ROOT_DIR)/tests/data/bbsim-kind-8x2.yaml
ROBOT_DEBUG_LOG_OPT             ?=
ROBOT_MISC_ARGS                 ?=

ROBOT_SYSTEM_SETUP_MISC_ARGS    ?= -i scaledown -l systemup_log.html -r systemup_report.html -o systemup_output.xml
ROBOT_SYSTEM_TEARDOWN_MISC_ARGS ?= -i scaleup -l systemdown_log.html -r systemdown_report.html -o sysstemdown_output.xml
ROBOT_SYSTEM_FILE               ?= K8S_SystemTest.robot

## Variables for gendocs
TEST_SOURCE := $(wildcard tests/*/*.robot)
TEST_BASENAME := $(basename $(TEST_SOURCE))
TEST_DIRS := $(dir $(TEST_SOURCE))

LIB_SOURCE := $(wildcard libraries/*.robot)
LIB_BASENAME := $(basename $(LIB_SOURCE))
LIB_DIRS := $(dir $(LIB_SOURCE))

# for backwards compatibility
sanity-kind: sanity-single-kind

sanity-single-kind: ROBOT_MISC_ARGS += -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
sanity-single-kind: bbsim-kind

rwcore-restart-single-kind: ROBOT_MISC_ARGS += -X -i bbsimANDrwcore-restart $(ROBOT_DEBUG_LOG_OPT)
rwcore-restart-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_FAIL_SINGLE_PON_FILE)
rwcore-restart-single-kind: ROBOT_FILE := Voltha_PODTests.robot
rwcore-restart-single-kind: voltha-test

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

system-scale-test: ROBOT_FILE := Voltha_PODTests.robot
system-scale-test: ROBOT_MISC_ARGS += -X -i sanity
system-scale-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
system-scale-test: k8s-system-test

failure-test: ROBOT_MISC_ARGS += -X -i FailureTest $(ROBOT_DEBUG_LOG_OPT)
failure-test: ROBOT_FILE := $(ROBOT_SYSTEM_FILE)
failure-test: ROBOT_CONFIG_FILE := $(ROBOT_FAIL_SINGLE_PON_FILE)
failure-test: voltha-test

voltha-test: ROBOT_MISC_ARGS += -e notready
k8s-system-test: ROBOT_MISC_ARGS += -e notready

# virtualenv for the robot tools
vst_venv:
	virtualenv -p python3 $@ ;\
	source ./$@/bin/activate ;\
	pip install -r requirements.txt

test: lint-robot lint-python lint-yaml lint-json

lint-robot: vst_venv
	source ./$</bin/activate ; set -u ;\
	rflint $(LINT_ARGS) $(ROBOT_FILES)

# check deps for format and python3 cleanliness
lint-python: vst_venv
	source ./$</bin/activate ; set -u ;\
	pylint --py3k $(PYTHON_FILES) ;\
	flake8 $(PYTHON_FILES)

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

voltha-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/functional ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

#bbsim-only
k8s-system-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/functional ;\
	robot $(ROBOT_SYSTEM_SETUP_MISC_ARGS) $(ROBOT_MISC_ARGS) $(ROBOT_SYSTEM_FILE) && \
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE) && \
	robot $(ROBOT_SYSTEM_TEARDOWN_MISC_ARGS) $(ROBOT_MISC_ARGS) $(ROBOT_SYSTEM_FILE)

.PHONY: gendocs
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
