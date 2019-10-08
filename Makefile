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

# Variables
LINT_ARGS   ?= --verbose --configure LineTooLong:120 --configure TooManyTestSteps:15
VERSION     ?= $(shell cat ./VERSION)
ROBOT_OLT_SN  =
ROBOT_ONU_SN  =

ifneq ($(BBSIM_OLT_SN),)
ROBOT_OLT_SN=-v BBSIM_OLT_SN:$(BBSIM_OLT_SN)
endif

ifneq ($(BBSIM_ONU_SN),)
ROBOT_ONU_SN=-v BBSIM_ONU_SN:$(BBSIM_ONU_SN)
endif

.PHONY: gendocs

## Variables for gendocs
TEST_SOURCE := $(wildcard tests/*/*.robot)
TEST_BASENAME := $(basename $(TEST_SOURCE))
TEST_DIRS := $(dir $(TEST_SOURCE))

LIB_SOURCE := $(wildcard libraries/*.robot)
LIB_BASENAME := $(basename $(LIB_SOURCE))
LIB_DIRS := $(dir $(LIB_SOURCE))


sanity-kind: ROBOT_PORT_ARGS ?= -v ONOS_REST_PORT:8181 -v ONOS_SSH_PORT:8101
sanity-kind: ROBOT_TEST_ARGS ?= --exclude notready --critical sanity
sanity-kind: ROBOT_MISC_ARGS ?= -v num_onus:1
sanity-kind: sanity

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

sanity: vst_venv
	source ./vst_venv/bin/activate ;\
	set -u ;\
	cd tests/sanity ;\
	robot $(ROBOT_PORT_ARGS) $(ROBOT_TEST_ARGS) $(ROBOT_MISC_ARGS) $(ROBOT_OLT_SN) $(ROBOT_ONU_SN) sanity.robot


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
