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
.PHONY: lint-doc8 lint-doc8-all lint-doc8-modified

have-doc8-files := $(if $(strip $(DOC8_SOURCE)),true)
DOC8_SOURCE     ?= $(error DOC8_SOURCE= is required)

##--------------------##
##---]  INCLUDES  [---##
##--------------------##
# include $(ONF_MAKEDIR)/lint/doc8/help.mk
include $(ONF_MAKEDIR)/lint/doc8/install.mk

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
ifndef NO-LINT-DOC8
  lint-doc8-mode := $(if $(have-doc8-files),modified,all)
  lint : lint-doc8-$(lint-doc8-mode)
endif# NO-LINT-DOC8

# Consistent targets across lint makefiles
lint-doc8-all      : lint-doc8
lint-doc8-modified : lint-doc8

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
lint-doc8-excl := $(foreach dir,$(onf-excl-dirs),--ignore-path "$(dir)")
lint-doc8: lint-doc8-cmd-version

	$(call banner-enter,Target $@)
	$(activate) && doc8 --version
	@echo
	$(activate) && doc8 $(lint-doc8-excl)
	$(call banner-enter,Target $@)

## -----------------------------------------------------------------------
## Intent: Display command usage
## -----------------------------------------------------------------------
help::
	@echo '  lint-doc8          Syntax check python using the doc8 command'
  ifdef VERBOSE
	@echo '  lint-doc8-all       doc8 checking: exhaustive'
	@echo '  lint-doc8-modified  doc8 checking: only modified'
  endif

# [EOF]
