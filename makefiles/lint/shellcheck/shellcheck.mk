# -*- makefile -*-
# -----------------------------------------------------------------------
# Copyright 2022-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
# https://gerrit.opencord.org/plugins/gitiles/onf-make
# ONF.makefile.version = 1.0
# -----------------------------------------------------------------------

##-------------------##
##---]  GLOBALS  [---##
##-------------------##

shell-check    := $(env-clean) shellcheck

shell-check-args += --check-sourced
shell-check-args += --external-sources

##-------------------##
##---]  TARGETS  [---##
##-------------------##
ifndef NO-LINT-SHELLCHECK
  lint : lint-shellcheck
endif

## -----------------------------------------------------------------------
## Intent: Perform a lint check on command line script sources
## -----------------------------------------------------------------------
lint-shellcheck: # shellcheck-version

	$(call banner-enter,Target $@)
	$(call gen-shellcheck-find-cmd) \
	    | $(xargs-cmd-clean) -I'{}' \
	        bash -c "$(shell-check) $(shell-check-args) {}"
	$(call banner-leave,Target $@)

## -----------------------------------------------------------------------
## Intent: Display yamllint command version string.
##   Note: As a side effect, install yamllint by dependency
## -----------------------------------------------------------------------
.PHONY: shellcheck-cmd-version
shellcheck-cmd-version :

	@echo
	$(shell-check) -V

## -----------------------------------------------------------------------
## Intent: Display command help
## -----------------------------------------------------------------------
help-summary ::
	@echo '  lint-shellcheck          Syntax check shell sources'

# [SEE ALSO]
# -----------------------------------------------------------------------
#   o https://www.shellcheck.net/wiki/Directive

# [EOF]
