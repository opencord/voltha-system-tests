#!/usr/bin/env bash

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

# licensecheck.sh
# checks for copyright/license headers on files
# excludes filename extensions where this check isn't pertinent

# --strict
# --strict-dates
#    see https://github...

## ---------------------------------------------------------------------------
## find: warning: ‘-name’ matches against basenames only, but the given pattern
## contains a directory separator (‘/’), thus the expression will evaluate to
## false all the time.  Did you mean ‘-wholename’?
##
## [TODO] find and fix plugin script, change --name to --path:
##    find ! -name "*/docs/*" 
## ---------------------------------------------------------------------------
## [TODO] see license/include.mk, grep -L will ignore binaries so no need to
## explicitly filter images, spreadsheets, etc.  Files containing utf-8 are
## the only question mark.
## ---------------------------------------------------------------------------

<<<<<<< HEAD
echo "BLAH"
exit 1

=======
>>>>>>> dc6caae ([VOL-5064] - Build and deploy voltha-system-tests)
set +e -u -o pipefail
fail_licensecheck=0

declare -a gargs=()
gargs+=('--extended-regexp')

# Evil regex -- scripts detecting pattern are excluded from checking.
gargs+=('-e' 'Apache License')

# Good regex -- no false positives.
gargs+=('-e' 'Copyright[[:space:]]+[[:digit:]]{4}')

while IFS= read -r -d '' path
do
<<<<<<< HEAD
    case "$path" in
	*venv*) echo "GERR: $path"
		exit 1
		;;
    esac
=======
>>>>>>> dc6caae ([VOL-5064] - Build and deploy voltha-system-tests)
    if ! grep -q "${gargs[@]}" "${path}";
    then
	echo "ERROR: $path does not contain License Header"
	fail_licensecheck=1
    fi
<<<<<<< HEAD
done < <(find . \( -name ".git" -o -name '.venv' -o 'vst_venv' \) -prune -o -type f \
=======
done < <(find . -name ".git" -prune -o -type f \
>>>>>>> dc6caae ([VOL-5064] - Build and deploy voltha-system-tests)
  ! -iname "*.png" \
  ! -name "*.asc" \
  ! -name "*.bat" \
  ! -name "*.bin" \
  ! -name "*.cert" \
  ! -name "*.cfg" \
  ! -name "*.cnf" \
  ! -name "*.conf" \
  ! -name "*.cql" \
  ! -name "*.crt" \
  ! -name "*.csar" \
  ! -name "*.csr" \
  ! -name "*.csv" \
  ! -name "*.ctmpl" \
  ! -name "*.curl" \
  ! -name "*.db" \
  ! -name "*.der" \
  ! -name "*.desc" \
  ! -name "*.diff" \
  ! -name "*.dnsmasq" \
  ! -name "*.do" \
  ! -name "*.docx" \
  ! -name "*.eot" \
  ! -name "*.gif" \
  ! -name "*.gpg" \
  ! -name "*.graffle" \
  ! -name "*.ico" \
  ! -name "*.iml" \
  ! -name "*.in" \
  ! -name "*.inc" \
  ! -name "*.install" \
  ! -name "*.j2" \
  ! -name "*.jar" \
  ! -name "*.jks" \
  ! -name "*.jpg" \
  ! -name "*.json" \
  ! -name "*.jsonld" \
  ! -name "*.JSON" \
  ! -name "*.key" \
  ! -name "*.list" \
  ! -name "*.local" \
  ! -path "*.lock" \
  ! -name "*.log" \
  ! -name "*.mak" \
  ! -name "*.md" \
  ! -name "*.MF" \
  ! -name "*.oar" \
  ! -name "*.p12" \
  ! -name "*.patch" \
  ! -name "*.pb.go" \
  ! -name "*.pb.gw.go" \
  ! -name "*.pdf" \
  ! -name "*.pcap" \
  ! -name "*.pem" \
  ! -name "*.properties" \
  ! -name "*.proto" \
  ! -name "*.protoset" \
  ! -name "*.pyc" \
  ! -name "*.repo" \
  ! -name "*.robot" \
  ! -name "*.rst" \
  ! -name "*.rules" \
  ! -name "*.service" \
  ! -name "*.svg" \
  ! -name "*.swp" \
  ! -name "*.tar" \
  ! -name "*.tar.gz" \
  ! -name "*.toml" \
  ! -name "*.ttf" \
  ! -name "*.txt" \
  ! -name "*.woff" \
  ! -name "*.xproto" \
  ! -name "*.xtarget" \
  ! -name "*ignore" \
  ! -name "*rc" \
  ! -name "*_pb2.py" \
  ! -name "*_pb2_grpc.py" \
  ! -name "Dockerfile" \
  ! -name "Dockerfile.*" \
  ! -name "go.mod" \
  ! -name "go.sum" \
  ! -name "README" \
  ! -path "*/vendor/*" \
  ! -path "*conf*" \
  ! -path "*git*" \
  ! -path "*swagger*" \
  ! -path "*.drawio" \
  ! -name "*.pb.h" \
  ! -name "*.pb.cc" \
  ! -path "*/docs/*" \
<<<<<<< HEAD
  ! -name 'output.xml' \
  ! -path "*/vst_venv/*" \
=======
  ! -name 'output.xml' \ 
  ! -path "*/.venv/*" \
>>>>>>> dc6caae ([VOL-5064] - Build and deploy voltha-system-tests)
  ! -name '*#*' \
  ! -path '*scripts/flog/*' \
  ! -name '*~' \
  ! -name 'VERSION' \
  ! -name 'patch' \
  -print0 )

exit ${fail_licensecheck}
