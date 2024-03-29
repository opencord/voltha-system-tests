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

MAKEDIR ?= $(error MAKEDIR= is required)

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
help::
	@echo "  kail            Install the kail command"
ifdef VERBOSE
	@echo "                  make kail KAIL_PATH="
	@echo "    export WORKSPACE=$(/bin/pwd) # i_am=jenkins"
endif

# -----------------------------------------------------------------------
# Install the 'kail' tool if needed: https://github.com/boz/kail
#   o WORKSPACE - jenkins aware
#   o Default to /usr/local/bin/kail
#       + revisit this, system directories should not be a default path.
#       + requires sudo and potential exists for overwrite conflict.
# -----------------------------------------------------------------------
KAIL_PATH ?= $(if $(WORKSPACE),$(WORKSPACE)/bin,/usr/local/bin)
# pin kail version to current latest usable releases (v0.17.0 did only publish
# source code, so we can't download the binary as tarball)
KAIL_VERSION ?= "v0.16.1"
kail-cmd  ?= $(KAIL_PATH)/kail
$(kail-cmd):
	mkdir -p "$(dir $@)"
	etc/godownloader.sh -b . "${KAIL_VERSION}"
	rsync -v --checksum kail "$@"
	$@ version
	$(RM) kail

.PHONY: kail
kail : $(kail-cmd)

# [EOF]
