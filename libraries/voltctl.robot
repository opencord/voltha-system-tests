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

# voltctl common functions

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
Create Device
    [Arguments]    ${ip}    ${port}
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${serial_number}
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${ip}:${port}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${device_id}

Enable Device
    [Arguments]    ${device_id}
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device enable ${device_id}
    Should Be Equal As Integers    ${rc}    0

Validate Device
    [Arguments]    ${serial_number}    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_reason}=${EMPTY}    ${onu}=False
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${serial_number}
    ...    Arguments are matched for device states of: "admin_state", "oper_status", and "connect_status"
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${astate}=    Get From Dictionary    ${value}    adminstate
    \    ${opstatus}=    Get From Dictionary    ${value}    operstatus
    \    ${cstatus}=    Get From Dictionary    ${value}    connectstatus
    \    ${sn}=    Get From Dictionary    ${value}    serialnumber
    \    ${mib_state}=    Get From Dictionary    ${value}    reason
    \    Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    Should Be Equal    ${astate}    ${admin_state}    Device ${serial_number} admin_state != ENABLED    values=False
    Should Be Equal    ${opstatus}    ${oper_status}    Device ${serial_number} oper_status != ACTIVE    values=False
    Should Be Equal    ${cstatus}    ${connect_status}    Device ${serial_number} connect_status != REACHABLE    values=False
    Run Keyword If    '${onu}' == 'True'    Should Be Equal    ${mib_state}    ${onu_reason}    Device ${serial_number} mib_state incorrect    values=False


Get Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${id}=    Get From Dictionary    ${value}    id
    \    ${sn}=    Get From Dictionary    ${value}    serialnumber
    \    Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    [Return]    ${id}

Validate Device Removed
    [Arguments]    ${id}
    [Documentation]    Verifys that device, ${serial_number}, has been removed
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    @{ids}=    Create List
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${device_id}=    Get From Dictionary    ${value}    id
    \    Append To List    ${ids}    ${device_id}
    List Should Not Contain Value    ${ids}    ${id}