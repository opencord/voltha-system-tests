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

ifdef VERBOSE
  help :: help-patches
else
  help ::
	@echo
	@echo "[PATCHES] - helper on the road to python 3.10+ based testing"
	@echo '  see also: help-patches'
endif

help-patches:
	@echo
	@echo "[PATCHES] - helper on the road to python 3.10+ based testing"
	@echo "  patch-apply          Apply patches to the virtualenv directory"
	@echo "  patch-create"
	@echo "  patch-gather         Gather a list of potential patch sources"
	@echo "  patch-init           Clone the virtualenv directory for patch creation."




help-trailer ::
	@echo "[SEE ALSO] patches-help"

help-verbose ::
	$(HIDE)$(MAKE) --no-print-directory help VERBOSE=1

# [EOF]
