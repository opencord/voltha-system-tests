# Copyright 2020-2023 Open Networking Foundation (ONF) and the ONF Contributors
# delivered by ADTRAN, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

*** Settings ***
Documentation     Library for basics of the dmi definition
Library           Collections
Library           BuiltIn

*** Variables ***

*** Keywords ***
Get Managed Devices
    [Documentation]     search and return for known/active devices
    [Arguments]    ${lib_instance}
    ${name_active_olts}=    Create List
    ${response}=    Run Keyword   ${lib_instance}.Hw Management Service Get Managed Devices
    Log    ${response}
    Check Dmi Status    ${response}    OK_STATUS
    ${keys}=    Create List
    ${keys}=    Get Dictionary Keys    ${response}
    ${devices_key_found}=    Set Variable    False
    ${length}=    Get Length    ${keys}
    FOR    ${I}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${keys}    ${I}
        ${devices_key_found}=    Set Variable If    '${value}'=='devices'    True    False
        Exit For Loop If    ${devices_key_found}
    END
    Return From Keyword If    '${devices_key_found}'=='False'    ${name_active_olts}
    ${devices}=     Get From Dictionary     ${response}     devices
    FOR    ${device}    IN    @{devices}
        ${name}=    Get From Dictionary    ${device}    name
        Append To List  ${name_active_olts}     ${name}
    END
    [Return]    ${name_active_olts}

Stop Managing Devices
    [Documentation]     remove given devices from device manager
    [Arguments]    ${lib_instance}  ${name_active_olts}
    FOR    ${device_name}    IN    @{name_active_olts}
        &{name}=    Evaluate    {'name':'${device_name}'}
        Run Keyword   ${lib_instance}.Hw Management Service Stop Managing Device    ${name}
    END

Search For Managed Devices And Stop Managing It
    [Documentation]     search for known/active devices and remove it from device manager
    [Arguments]    ${lib_instance}
    Run Keyword     ${lib_instance}.Connection Open    ${DEVICEMANAGER_IP}    ${DEVICEMANAGER_PORT}
    ${active_devices}=     Get Managed Devices   ${lib_instance}
    ${size}=    Get Length  ${active_devices}
    Run Keyword If   ${size} != ${0}   Stop Managing Devices      ${lib_instance}    ${active_devices}
    Run Keyword If   ${size} != ${0}    Fail    test case '${PREV_TEST_NAME}' failed!
    ${active_devices}=     Get Managed Devices   ${lib_instance}
    Should Be Empty     ${active_devices}
    Run Keyword 	 ${lib_instance}.Connection Close

Increment If Equal
    [Documentation]  increment given value if condition 1 and condition 2 is equal
    [Arguments]    ${condition_1}   ${condition_2}      ${value}
    ${value}=   Set Variable If  ${condition_1} == ${condition_2}
    ...   ${value+1}      ${value}
    [Return]    ${value}

Increment If Contained
    [Documentation]  increment given value 'string' contained in 'message'
    [Arguments]    ${message}   ${string}      ${value}
    ${hit}=   Run Keyword And Return Status    Should Contain   ${message}  ${string}
    ${value}=   Increment If Equal  ${hit}  ${True}  ${value}
    [Return]    ${value}

Start Managing Device
    [Documentation]     add a given device to the device manager
    [Arguments]    ${lib_instance}   ${olt_ip}    ${device_name}      ${check_result}=${True}
    ${dev_name}=    Convert To String    ${device_name}
    &{component}=    Evaluate    {'name':'${dev_name}', 'uri':{'uri':'${olt_ip}'}}
    ${response}=    Run Keyword   ${lib_instance}.Hw Management Service Start Managing Device    ${component}
    ${list}=    Get From List    ${response}    0
    Run Keyword If   ${check_result} == ${True}  Should Be Equal   ${list}[status]    OK_STATUS
    ${uuid}=    Get From Dictionary    ${list}    device_uuid
    [Return]  ${uuid}

Stop Managing Device
    [Documentation]     remove a given device from the device manager
    [Arguments]  ${lib_instance}   ${device_name}      ${check_result}=${True}
    &{name}=  Evaluate  {'name':'${device_name}'}
    ${response}=  Run Keyword   ${lib_instance}.Hw Management Service Stop Managing Device    ${name}
    Run Keyword If  ${check_result} == ${True}  Should Be Equal  ${response}[status]  OK_STATUS

Check Dmi Status
    [Documentation]  check if the given state in the given result
    [Arguments]  ${result}  ${state}
    ${state_in_result}=  Get From Dictionary  ${result}  status
    Should Be Equal  ${state}  ${state_in_result}
