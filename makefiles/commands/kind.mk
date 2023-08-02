# -*- makefile -*-
# -----------------------------------------------------------------------
# Copyright 2022-2023 Open Networking Foundation (ONF) and the ONF Contributors
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

MAKEDIR ?= $(error MAKEDIR= is required)

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
help::
	@echo "  kind            Install the kind command"
ifdef VERBOSE
	@echo "                  make kind KIND_PATH="
endif

kind-cmd-bin ?= kind-linux-amd64
# kind-cmd-ver ?= v0.20.0
kind-cmd-ver ?= v0.11.0

# -----------------------------------------------------------------------
# Install the 'kind' tool if needed: https://github.com/boz/kind
#   o WORKSPACE - jenkins aware
#   o Default to /usr/local/bin/kind
#       + revisit this, system directories should not be a default path.
#       + requires sudo and potential exists for overwrite conflict.
# -----------------------------------------------------------------------
KIND_PATH ?= $(if $(WORKSPACE),$(WORKSPACE)/bin,$(PWD)/bin)
kind-cmd  ?= $(KIND_PATH)/kind.$(kind-cmd-ver).$(kind-cmd-bin)
$(kind-cmd):
	@echo "kind-cmd = $(kind-cmd)"
	mkdir -p $(dir $(kind-cmd))
	curl --silent -Lo "$@" https://kind.sigs.k8s.io/dl/$(kind-cmd-ver)/$(kind-cmd-bin)
	chmod +x "$@"
	"$@" --version

bin/kind : $(kind-cmd)
	ln -fns $< $@

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
.PHONY: install-command-kind
install-command-kind : bin/kind

clean ::
	$(RM) bin/kind $(kind-cmd)

# [EOF]
