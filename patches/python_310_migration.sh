#!/bin/bash
# -----------------------------------------------------------------------
# Copyright 2022 Open Networking Foundation
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

set -euo pipefail

dst=".venv"   # was vst_venv
src="staging"
pat="patches"

declare -a fyls=()
fyls+=('lib/python3.10/site-packages/robot/utils/normalizing.py')
fyls+=('lib/python3.10/site-packages/robot/utils/robottypes3.py')

echo
echo "==========================================================================="
echo "CMD: $0"
echo "PWD: $(/bin/pwd)"
echo "ARGV: $*"
echo "==========================================================================="

if [ $# -eq 0 ]; then set -- apply; fi

while [ $# -gt 0 ]; do
    opt="$1"; shift
    case "$opt" in
	help)
	    cat <<EOH
apply  - generate patches from vault source.
backup - Archive patch directory
gather - collect potential python files to edit.
EOH
	    ;;

	apply)
	    pushd "$dst" || { echo "pushd $dst failed"; exit 1; }
	    for fyl in "${fyls[@]}";
	    do
		# Conditional install, jenkins may not support interpreter yet.
		if [ ! -e "$fyl" ]; then
		    echo "[SKIP] No venv file to patch: $fyl"
		    continue
		fi
		
		echo "$fyl"
		patch -R -p1 < "../$pat/$fyl/patch"
	    done
	    popd || { echo "popd $dst failed"; exit 1; }
	    ;;

	backup)
	    mkdir ~/backups
	    pushd "$src" || { echo "pushd $dst failed"; exit 1; }
	    tar czvf ~/backups/vault."$(date '+%Y%m%d%H%M%S')" "${fyls[@]}"
	    popd || { echo "popd $dst failed"; exit 1; }
	    ;;

	gather)
	    set -x
	    for fyl in "${fyls[@]}";
	    do
		patchDir="$pat/$fyl"
		mkdir -p "$patchDir"
		diff -Naur "$src/$fyl" "$dst/$fyl" | tee "$pat/$fyl/patch"
	    done
	    find "$pat" -print
	    set +x
	    ;;
	
	*)
	    echo "ERROR: Unknown action [$opt]"
	    exit 1
	    ;;
    esac
done

# [EOF]
