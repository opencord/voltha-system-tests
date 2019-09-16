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

# Arguments
LINT_ARGS 	?= --verbose --configure LineTooLong:120 --configure TooManyTestSteps:15

# virtualenv for the robot tools
vst_venv:
	virtualenv $@ ;\
	source ./$@/bin/activate ;\
	pip install -r requirements.txt

test: lint

lint: vst_venv
	source ./vst_venv/bin/activate ;\
	set -u ;\
	rflint $(LINT_ARGS) tests libraries variables

sanity: vst_venv
	source ./vst_venv/bin/activate ;\
	set -u ;\
	cd tests/sanity ;\
	robot --exclude notready sanity.robot

clean:

# find . -name output.xml -name report.xml -name log.html -print

clean-all: clean
	rm -rf vst_venv
