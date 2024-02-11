# -*- makefile -*-
# -----------------------------------------------------------------------
# Copyright 2017-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
.PHONY: lint-mdl lint-mdl-all lint-mdl-modified

have-rst-files := $(if $(strip $(RST_SOURCE)),true)
RST_SOURCE     ?= $(error RST_SOURCE= is required)

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
ifndef NO-LINT-MARKDOWN
  lint-mdl-mode := $(if $(have-mdl-files),modified,all)
  lint : lint-mdl-$(lint-mdl-mode)
endif# NO-LINT-MDL

# Consistent targets across lint makefiles
lint-mdl-all      : lint-mdl
lint-mdl-modified : lint-mdl

# onf-excl-dirs
LINT_STYLE ?= mdl_strict.rb

mdl-excludes := $(foreach path,$(onf-exclude-dirs),! -path "./$(path)/*")

lint-mdl:
	$(call banner-enter,Target $@)
	@echo "markdownlint(mdl) version: `mdl --version`"
	@echo "style config:"
	@echo "---"
	@cat $(LINT_STYLE)
	@echo "---"
# 	mdl -s $(LINT_STYLE) `find -L $(SOURCEDIR) ! -path "./_$(venv-activate-script)/*" ! -path "./_build/*" ! -path "./repos/*" ! -path "*vendor*" -name "*.md"`
	mdl -s $(LINT_STYLE) `find -L $(SOURCEDIR) $(mdl-excludes) -iname "*.md"`

## -----------------------------------------------------------------------
## Intent: Display command usage
## -----------------------------------------------------------------------
help::
	@echo '  lint-mdl          Syntax check python using the mdl command'
  ifdef VERBOSE
	@echo '  lint-mdl-all       mdl checking: exhaustive'
	@echo '  lint-mdl-modified  mdl checking: only modified'
  endif

# [EOF]
