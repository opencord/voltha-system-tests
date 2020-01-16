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
Documentation     Library for Digital Loggers Web Power Switch
                  ...    Official Document: https://www.digital-loggers.com/rest.html
Library           Collections
Library           RequestsLibrary

*** Variables ***
${timeout}       60s
${alias_name}    Switch Outlet
${restapi_uri}   restapi/relay/outlets/

*** Keywords ***
Power Switch Connection Suite
    [Arguments]    ${ip}    ${username}    ${password}
    [Documentation]    Setup The HTTP Session To Web Power Switch
    ${auth}=    Create List    ${username}    ${password}
    ${headers}=    Create Dictionary
    Set To Dictionary    ${headers}    X-CSRF    x
    Set To Dictionary    ${headers}    Content-Type    application/x-www-form-urlencoded
    Create Digest Session    alias=${alias_name}    url=http://${ip}/${restapi_uri}
    ...    auth=${auth}    headers=${headers}

Enable Switch Outlet
    [Arguments]    ${port}
    [Documentation]    Enable the Web Switch Outlet
    ${resp}=    Put Request    alias=${alias_name}    uri==${port}/state/    data=value=true
    Should Be Equal As Strings  ${resp.status_code}  207
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Switch Outlet Status    ${port}    true

Disable Switch Outlet
    [Arguments]    ${port}
    [Documentation]    Disable the Web Switch Outlet
    ${resp}=    Put Request    alias=${alias_name}    uri==${port}/state/    data=value=false
    Should Be Equal As Strings  ${resp.status_code}  207
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Switch Outlet Status    ${port}    false

Check Expected Switch Outlet Status
    [Arguments]    ${port}    ${status}
    [Documentation]    Succeeds if the desired switch outlet status is expected
    ${resp}=    Get Request    alias=${alias_name}    uri==${port}/state/
    Should Be Equal As Strings  ${resp.text}  [${status}]
