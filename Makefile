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
SHELL = bash -e -o pipefail
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Variables
LINT_ARGS   ?= --verbose --configure LineTooLong:120 --configure TooManyTestSteps:15 \
       --configure TooFewTestSteps:1 --configure TooFewKeywordSteps:1
VERSION     ?= $(shell cat ./VERSION)
ROBOT_SANITY_SINGLE_PON_FILE ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_MULT_PON_FILE ?= $(ROOT_DIR)/tests/data/bbsim-kind-2x2.yaml
ROBOT_SCALE_SINGLE_PON_FILE ?= $(ROOT_DIR)/tests/data/bbsim-kind-16.yaml
ROBOT_SCALE_MULT_PON_FILE ?= $(ROOT_DIR)/tests/data/bbsim-kind-8x2.yaml

ROBOT_SYSTEM_SETUP_MISC_ARGS ?= -i scaledown -l systemup_log.html -r systemup_report.html -o systemup_output.xml
ROBOT_SYSTEM_TEARDOWN_MISC_ARGS ?= -i scaleup -l systemdown_log.html -r systemdown_report.html -o sysstemdown_output.xml
ROBOT_SYSTEM_FILE ?= K8S_SystemTest.robot

.PHONY: gendocs

## Variables for gendocs
TEST_SOURCE := $(wildcard tests/*/*.robot)
TEST_BASENAME := $(basename $(TEST_SOURCE))
TEST_DIRS := $(dir $(TEST_SOURCE))

LIB_SOURCE := $(wildcard libraries/*.robot)
LIB_BASENAME := $(basename $(LIB_SOURCE))
LIB_DIRS := $(dir $(LIB_SOURCE))

ROBOT_MISC_ARGS ?=

# for backwards compatibility
sanity-kind: sanity-single-kind

sanity-single-kind: ROBOT_MISC_ARGS += -i sanity
sanity-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
sanity-single-kind: bbsim-kind

sanity-multi-kind: ROBOT_MISC_ARGS += -i sanity
sanity-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
sanity-multi-kind: bbsim-kind

bbsim-kind: ROBOT_MISC_ARGS += -X
bbsim-kind: ROBOT_FILE := Voltha_PODTests.robot
bbsim-kind: voltha-test

scale-single-kind: ROBOT_MISC_ARGS += -i active
scale-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_SINGLE_PON_FILE)
scale-single-kind: bbsim-scale-kind

scale-multi-kind: ROBOT_MISC_ARGS += -i active
scale-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_MULT_PON_FILE)
scale-multi-kind: bbsim-scale-kind

bbsim-scale-kind: ROBOT_MISC_ARGS += -X
bbsim-scale-kind: ROBOT_FILE := Voltha_ScaleFunctionalTests.robot
bbsim-scale-kind: voltha-test

system-scale-test: ROBOT_FILE := Voltha_PODTests.robot
system-scale-test: ROBOT_MISC_ARGS += -X -i sanity
system-scale-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
system-scale-test: k8s-system-test

# virtualenv for the robot tools
vst_venv:
	virtualenv $@ ;\
	source ./$@/bin/activate ;\
	pip install -r requirements.txt

test: lint

lint: vst_venv
	source ./vst_venv/bin/activate ;\
	set -u ;\
	find . -name *.robot -exec rflint $(LINT_ARGS) {} +

# tidy will be more useful once this issue with removing leading comments is
# resolved: https://github.com/robotframework/robotframework/issues/3263
tidy:
	source ./vst_venv/bin/activate ;\
	set -u ;\
	find . -name *.robot -exec python -m robot.tidy --inplace {} \;

voltha-test: vst_venv
	source ./vst_venv/bin/activate ;\
	set -u ;\
	cd tests/functional ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

#bbsim-only
k8s-system-test: vst_venv
	source ./vst_venv/bin/activate ;\
	set -u ;\
	cd tests/functional ;\
	robot $(ROBOT_SYSTEM_SETUP_MISC_ARGS) $(ROBOT_MISC_ARGS) $(ROBOT_SYSTEM_FILE) && \
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE) && \
	robot $(ROBOT_SYSTEM_TEARDOWN_MISC_ARGS) $(ROBOT_MISC_ARGS) $(ROBOT_SYSTEM_FILE)

gendocs: vst_venv
	source ./vst_venv/bin/activate ;\
	set -u ;\
	mkdir -p $@ ;\
	for dir in ${LIB_DIRS}; do mkdir -p $@/$$dir; done;\
	for dir in ${LIB_BASENAME}; do\
		python -m robot.libdoc --format HTML $$dir.robot $@/$$dir.html ;\
	done ;\
	for dir in ${TEST_DIRS}; do mkdir -p $@/$$dir; done;\
	for dir in ${TEST_BASENAME}; do\
		python -m robot.testdoc $$dir.robot $@/$$dir.html ;\
	done

# explore use of --docformat REST - integration w/Sphinx?
clean:
	find . -name output.xml -print

clean-all: clean
	rm -rf vst_venv gendocs
