# Copyright 2017-present Open Networking Foundation
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

*** Variables ***
${BBSIM_OLT_SN}    BBSIM_OLT_0
${BBSIM_ONU_SN}    BBSM00000001
${ONOS_REST_PORT}    30120
${ONOS_SSH_PORT}    30115
${OLT_PORT}       9191
@{PODLIST1}       voltha-kafka    voltha-ofagent
@{PODLIST2}       bbsim    etcd-operator-etcd-operator-etcd-operator    radius    voltha-api-server
...               voltha-cli-server    voltha-ro-core    voltha-rw-core-11
