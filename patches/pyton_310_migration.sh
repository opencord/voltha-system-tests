#!/bin/bash
## -----------------------------------------------------------------------
## Intent: A makefile helper script used to generate and apply patches.
## -----------------------------------------------------------------------

set -euo pipefail

dst="vst_venv"
src="staging"
pat="patches"

declare -a fyls=()
fyls+=('lib/python3.10/site-packages/robot/utils/normalizing.py')
fyls+=('lib/python3.10/site-packages/robot/utils/robottypes3.py')

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
	    for fyl in "${fyls[@]}";
	    do
		patchDir="$pat/$fyl"
		mkdir -p "$patchDir"
		diff -Naur "$src/$fyl" "$dst/$fyl" | tee "$pat/$fyl/patch"
	    done
	    find "$pat" -print
	    ;;
	
	*)
	    echo "ERROR: Unknown action [$opt]"
	    exit 1
	    ;;
    esac
done
