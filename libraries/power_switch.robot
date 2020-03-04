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

*** Settings ***
Documentation     Library for Web Power Switch, support DLI(Digital Loggers)
                  ...    and EPC(Expert Power Control)
Library           Collections
Library           RequestsLibrary

*** Variables ***
${timeout}       60s
${alias_name}    Switch Outlet

*** Keywords ***
Power Switch Connection Suite
    [Arguments]    ${ip}    ${username}    ${password}
    [Documentation]    Setup The HTTP Session To Web Power Switch
    Variable Should Exist    ${powerswitch_type}
    ...    'Miss Global Variable powerswitch_type, available options are EPC, DLI'
    Run Keyword IF    '${powerswitch_type}' == 'DLI'    Setup DLI Power Switch    ${ip}    ${username}    ${password}
    ...    ELSE IF    '${powerswitch_type}' == 'EPC'    Setup EPC Power Switch    ${ip}    ${username}    ${password}
    ...    ELSE    Fail    'The Power Switch Type unsupported: ${powerswitch_type}'

Enable Switch Outlet
    [Arguments]    ${outlet_number}
    [Documentation]    Enable specific outlet of the Web Power Switch
    Variable Should Exist    ${powerswitch_type}
    ...    'Miss Global Variable powerswitch_type, available options are EPC, DLI'
    Run Keyword IF    '${powerswitch_type}' == 'DLI'    Enable DLI Switch Outlet   ${outlet_number}
    ...    ELSE IF    '${powerswitch_type}' == 'EPC'    Enable EPC Switch Outlet   ${outlet_number}
    ...    ELSE    Fail    'The Power Switch Type unsupported: ${powerswitch_type}'


Disable Switch Outlet
    [Arguments]    ${outlet_number}
    [Documentation]    Disable specific outlet of the web Power Switch
    Variable Should Exist    ${powerswitch_type}
    ...    'Miss Global Variable powerswitch_type, available options are EPC, DLI'
    Run Keyword IF    '${powerswitch_type}' == 'DLI'    Disable DLI Switch Outlet   ${outlet_number}
    ...    ELSE IF    '${powerswitch_type}' == 'EPC'    Disable EPC Switch Outlet   ${outlet_number}
    ...    ELSE    Fail    'The Power Switch Type unsupported: ${powerswitch_type}'

Check Expected Switch Outlet Status
    [Arguments]    ${outlet_number}    ${status}
    [Documentation]    Succeeds if the status of the desired switch outlet is expected
    Variable Should Exist    ${powerswitch_type}
    ...    'Miss Global Variable powerswitch_type, available options are EPC, DLI'
    Run Keyword IF    '${powerswitch_type}' == 'DLI'    Check Expected DLI Switch Outlet Status    ${outlet_number}
    ...    ELSE IF    '${powerswitch_type}' == 'EPC'    Check Expected EPC Switch Outlet Status    ${outlet_number}
    ...    ELSE    Fail    'The Power Switch Type unsupported: ${powerswitch_type}'

#Intenal Use Only
Setup DLI Power Switch
    [Arguments]    ${ip}    ${username}    ${password}
    [Documentation]    Setup The HTTP Session To Web Power Switch
    ${auth}=    Create List    ${username}    ${password}
    ${headers}=    Create Dictionary
    Set To Dictionary    ${headers}    X-CSRF    x
    Set To Dictionary    ${headers}    Content-Type    application/x-www-form-urlencoded
    Create Digest Session    alias=${alias_name}    url=http://${ip}/restapi/relay/outlets/
    ...    auth=${auth}    headers=${headers}

Setup EPC Power Switch
    [Arguments]    ${ip}    ${username}    ${password}
    [Documentation]    Setup The HTTP Session To Web Power Switch
    ${auth}=    Create List    ${username}    ${password}
    ${headers}=    Create Dictionary
    Set To Dictionary    ${headers}    X-CSRF    x
    Set To Dictionary    ${headers}    Content-Type    application/x-www-form-urlencoded
    Create Digest Session    alias=${alias_name}    url=http://${ip}
    ...    auth=${auth}    headers=${headers}


Enable DLI Switch Outlet
    [Arguments]    ${outlet_number}
    [Documentation]    Enable specific outlet of DLI power switch
    ${resp}=    Put Request    alias=${alias_name}    uri==${outlet_number}/state/    data=value=true
    Should Be Equal As Strings  ${resp.status_code}  207
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected DLI Switch Outlet Status    ${outlet_number}    true

Enable EPC Switch Outlet
    [Arguments]    ${outlet_number}
    [Documentation]    Enable specific outlet of EPC power switch
    ${resp}=    Get Request    alias=${alias_name}    uri=ov.html?cmd=1&p=${outlet_number}&s=1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected EPC Switch Outlet Status    ${outlet_number}    1

Disable DLI Switch Outlet
    [Arguments]    ${outlet_number}
    [Documentation]    Disable specific outlet of DLI Power Switch
    ${resp}=    Put Request    alias=${alias_name}    uri==${outlet_number}/state/    data=value=false
    Should Be Equal As Strings  ${resp.status_code}  207
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected DLI Switch Outlet Status    ${outlet_number}    false

Disable EPC Switch Outlet
    [Arguments]    ${outlet_number}
    [Documentation]    Disable specific outlet of EPC Power Switch
    ${resp}=    Get Request    alias=${alias_name}    uri=ov.html?cmd=1&p=${outlet_number}&s=0
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected EPC Switch Outlet Status    ${outlet_number}    0

Check Expected DLI Switch Outlet Status
    [Arguments]    ${outlet_number}    ${status}
    [Documentation]    Succeeds if the status of the desired DLI switch outlet is expected
    ${resp}=    Get Request    alias=${alias_name}    uri==${outlet_number}/state/
    Should Be Equal As Strings  ${resp.text}  [${status}]

Check Expected EPC Switch Outlet Status
    [Arguments]    ${outlet_number}    ${status}
    [Documentation]    Succeeds if the status of the desired EPC switch outlet is expected
    ${resp}=    Get Request    alias=${alias_name}    uri=statusjsn.js?components=1
    ${outlet_number}=  Convert To Number  ${outlet_number}
    ${rc}    ${outlet_status}    Run and Return Rc And Output    echo '${resp.text}' | jq -r .outputs[${outlet_number - 1}].state
    Should Be Equal As Integers    0    ${rc}
    Should Be Equal As Strings  ${outlet_status}  ${status}
