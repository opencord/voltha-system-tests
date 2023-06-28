# -*- makefile -*-
# -----------------------------------------------------------------------
# Copyright 2017-2023 Open Networking Foundation
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
.PHONY: lint-hadolint lint-hadolint-all lint-hadolint-modified

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
ifndef NO-LINT-HADOLINT
  have-rst-files := $(if $(strip $(RST_SOURCE)),true)
  RST_SOURCE     ?= $(error RST_SOURCE= is required)

  lint-hadolint-mode := $(if $(have-hadolint-files),modified,all)
  lint : lint-hadolint-$(lint-hadolint-mode)
endif# NO-LINT-HADOLINT

# Consistent targets across lint makefiles
lint-hadolint-all      : lint-hadolint
lint-hadolint-modified : lint-hadolint

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
include $(MAKEDIR)/lint/hadolint/excl.mk

ifdef lint-hadolint-excl
  lint-hadolint-excl-args += $(addprefix --ignore-path$(space),$(lint-hadolint-excl))
endif
lint-hadolint-excl-args += $(addprefix --ignore-path$(space),$(lint-hadolint-excl-raw))

lint-hadolint-args += --max-line-length 120

lint-hadolint: $(venv-activate-script)
	@echo
	@echo '** -----------------------------------------------------------------------'
	@echo '** hadolint *.rst syntax checking'
	@echo '** -----------------------------------------------------------------------'
	$(activate) && hadolint --version
	@echo
	$(activate) && hadolint $(lint-hadolint-excl-args) $(lint-hadolint-args) .

## -----------------------------------------------------------------------
## Intent: Display command usage
## -----------------------------------------------------------------------
help::
	@echo '  lint-hadolint          Syntax check python using the hadolint command'
  ifdef VERBOSE
	@echo '  lint-hadolint-all       hadolint checking: exhaustive'
	@echo '  lint-hadolint-modified  hadolint checking: only modified'
  endif

# include $(MAKEDIR)/lint/docker/hadolint.mk

# [EOF]
