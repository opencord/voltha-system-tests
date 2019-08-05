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

# robot test functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           HttpLibrary.HTTP
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Execute ONOS Command
    [Arguments]    ${cmd}
    [Documentation]    Establishes an ssh connection to the onos contoller and executes a command
    ${conn_id}=    SSHLibrary.Open Connection    localhost    port=8101    prompt=onos>    timeout=300s
    SSHLibrary.Login    karaf    karaf
    ${output}=    SSHLibrary.Execute Command    ${cmd}
    SSHLibrary.Close Connection
    [Return]    ${output}

Validate Device
    [Arguments]    ${serial_number}    ${admin_state}    ${oper_status}    ${connect_status}
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${serial_number}
    ...    Arguments are matched for device states of: "admin_state", "oper_status", and "connect_status"
    ${output}=    Run    ${VOLTCTL_CONFIG} voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${astate}=    Get From Dictionary    ${value}    adminstate
    \    ${opstatus}=    Get From Dictionary    ${value}    operstatus
    \    ${cstatus}=    Get From Dictionary    ${value}    connectstatus
    \    ${sn}=    Get From Dictionary    ${value}    serialnumber
    \    Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    Should Be Equal    ${astate}    ${admin_state}    Device ${serial_number} admin_state != ENABLED    values=False
    Should Be Equal    ${opstatus}    ${oper_status}    Device ${serial_number} oper_status != ACTIVE    values=False
    Should Be Equal    ${cstatus}    ${connect_status}    Device ${serial_number} connect_status != REACHABLE    values=False

Check CLI Tools Configured
    [Documentation]    Tests that use 'voltctl' and 'kubectl' should execute this keyword in suite setup
    # check voltctl and kubectl configured
    ${voltctl_rc}=    Run And Return RC    ${VOLTCTL_CONFIG} voltctl
    ${kubectl_rc}=    Run And Return RC    ${KUBECTL_CONFIG} kubectl
    Run Keyword If    ${voltctl_rc} != 0 or ${kubectl_rc} != 0    FATAL ERROR
    ...    VOLTCTL and KUBECTL not configured. Please configure before executing tests.
