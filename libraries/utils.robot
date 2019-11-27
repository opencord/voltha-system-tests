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
Check CLI Tools Configured
    [Documentation]    Tests that use 'voltctl' and 'kubectl' should execute this keyword in suite setup
    # check voltctl and kubectl configured
    ${voltctl_rc}=    Run And Return RC    ${VOLTCTL_CONFIG}; voltctl device list
    ${kubectl_rc}=    Run And Return RC    ${KUBECTL_CONFIG}; kubectl get pods
    Run Keyword If    ${voltctl_rc} != 0 or ${kubectl_rc} != 0    FATAL ERROR
    ...    VOLTCTL and KUBECTL not configured. Please configure before executing tests.

Send File To Onos
    [Documentation]  Send the content of the file to Onos to selected section of configuration using Post Request
    [Arguments]  ${CONFIG_FILE}  ${section}
    ${Headers}=  Create Dictionary  Content-Type   application/json
    ${File_Data}=   Get Binary File   ${CONFIG_FILE}
    Log     ${Headers}
    Log     ${File_Data}
    ${resp}=   Post Request  ONOS  /onos/v1/network/configuration/${section}  headers=${Headers}   data=${File_Data}
    Should Be Equal As Strings    ${resp.status_code}  200

WPA Reassociate
    [Arguments]    ${iface}    ${ip}    ${user}    ${pass}=${None}    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]    Executes a particular wpa_cli reassociate, which performs force reassociation
    #Below for loops are used instead of sleep time, to execute reassociate command and check status
    : FOR    ${i}    IN RANGE    60
    \    ${output}=    Login And Run Command On Remote System    wpa_cli -i ${iface} reassociate    ${ip}    ${user}
    ...    ${pass}    ${container_type}    ${container_name}
    \    ${passed}=    Run Keyword And Return Status    Should Contain    ${output}    OK
    \    Run Keyword If    ${passed}    Exit For Loop
    : FOR    ${i}    IN RANGE    60
    \    ${output}=    Login And Run Command On Remote System    wpa_cli status | grep SUCCESS    ${ip}    ${user}
    ...    ${pass}    ${container_type}    ${container_name}
    \    ${passed}=    Run Keyword And Return Status    Should Contain    ${output}    SUCCESS
    \    Run Keyword If    ${passed}    Exit For Loop

Validate Authentication After Reassociate
    [Arguments]    ${auth_pass}    ${iface}    ${ip}    ${user}    ${pass}=${None}    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]    Executes a particular reassociate request on the RG using wpa_cli. auth_pass determines if authentication should pass
    WPA Reassociate    ${iface}    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'True'    Wait Until Keyword Succeeds    ${timeout}    2s    Check Remote File Contents
    ...    True    /tmp/wpa.log    authentication completed successfully    ${ip}    ${user}    ${pass}
    ...    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'False'    Sleep    20s
    Run Keyword If    '${auth_pass}' == 'False'    Check Remote File Contents    False    /tmp/wpa.log
    ...    authentication completed successfully    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}


