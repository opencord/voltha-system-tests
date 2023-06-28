# -*- makefile -*-
# -----------------------------------------------------------------------
# Copyright 2017-2022 Open Networking Foundation
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
# -----------------------------------------------------------------------

##-------------------##
##---]  GLOBALS  [---##
##-------------------##
.PHONY: lint-robot lint-robot-all lint-robot-modified

have-robot-files := $(if $(strip $(ROBOT_FILES)),true)
ROBOT_FILES ?= $(error ROBOT_FILES= is required)

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
ifndef NO-LINT-ROBOT
  lint-robot-mode := $(if $(have-robot-files),modified,all)
  lint : lint-robot-$(lint-robot-mode)
endif# NO-LINT-ROBOT

# Consistent targets across lint makefiles
lint-robot-all      : lint-robot
lint-robot-modified : lint-robot

LINT_ARGS ?= --verbose --configure LineTooLong:130 -e LineTooLong \
             --configure TooManyTestSteps:65 -e TooManyTestSteps \
             --configure TooManyTestCases:50 -e TooManyTestCases \
             --configure TooFewTestSteps:1 \
             --configure TooFewKeywordSteps:1 \
             --configure FileTooLong:2000 -e FileTooLong \
             -e TrailingWhitespace

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
lint-robot: $(venv-activate-script)
	@echo
	@echo '** -----------------------------------------------------------------------'
	@echo '** robot *.rst syntax checking'
	@echo '** -----------------------------------------------------------------------'
#	$(activate) && rflint --version
	$(activate) && rflint $(LINT_ARGS) $(ROBOT_FILES)

## -----------------------------------------------------------------------
## Intent: Display command usage
## -----------------------------------------------------------------------
help::
	@echo '  lint-robot          Syntax check python using the robot command'
  ifdef VERBOSE
	@echo '  lint-robot-all       robot checking: exhaustive'
	@echo '  lint-robot-modified  robot checking: only modified'
  endif

# [EOF]
