# Copyright 2019-present Open Networking Foundation
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
# voltha common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Lookup Pod That Owns Device
    [Arguments]    ${device_id}
    [Documentation]    Uses a utility script to lookup which RW Core has current ownership of an OLT
    ${rc}    ${pod}=    Run and Return Rc and Output
    ...    ../scripts/which_pod_owns_device.sh ${device_id}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${pod}

Lookup Deployment That Owns Device
    [Arguments]    ${device_id}
    [Documentation]    Uses a utility script to lookup which RW Core has current ownership of an OLT
    ${rc}    ${deploy}=    Run and Return Rc and Output
    ...    which_deployment_owns_device.sh ${device_id}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${deploy}

Restart VOLTHA Port Forward
    [Arguments]    ${name}
    [Documentation]    Uses a script to restart a kubectl port-forward
    ${cmd}	Catenate
    ...    ps e -ww -A |
    ...    grep -E "_TAG=([a-z_-]+-)?${name}" |
    ...    grep -v grep |
    ...    awk '{printf(\"%s %s\\n\",$1,$5)}' |
    ...    grep -v bash | awk '{print $1}'
    ${rc}    ${pid}    Run And Return Rc And Output    ${cmd}
    Should Be Equal as Integers    ${rc}    0
    Run Keyword If    '${pid}' != ''    Run And Return Rc    kill -9 ${pid}
    Should Be Equal as Integers    ${rc}    0

Get Kv Store Prefix
    [Documentation]    This keyword delivers the KV Store Prefix read from environment variable KVSTOREPREFIX if present.
    [Arguments]    ${defaultkvstoreprefix}=voltha_voltha
    ${kv_store_prefix}=    Get Environment Variable    KVSTOREPREFIX    default=${defaultkvstoreprefix}
    # while Get Environment Variable does not work correctly, a manual correction follows
    ${kv_store_prefix}=    Set Variable If    "${kv_store_prefix}"=="${EMPTY}"    ${defaultkvstoreprefix}    ${kv_store_prefix}
    [Return]    ${kv_store_prefix}

