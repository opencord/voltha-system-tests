# Copyright 2017-2023 Open Networking Foundation (ONF) and the ONF Contributors
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
Documentation     Library for IGMP Proxy Control Application interactions
Library           Collections

*** Variables ***

*** Keywords ***
Get Igmp Group Members List
    [Documentation]    Retrieves the IGMP group members using IGMPCA REST API
    [Arguments]    ${igmpca_rel_session}    ${group}
    @{group_members_list}=    Create List
    ${resp}=    Get Request    ${igmpca_rel_session}    /v1/members
    ${dict}=    Evaluate    json.loads(r'''${resp.content}''')    json
    Run Keyword If    "members" not in "&{dict}"
    ...    Return From Keyword    ${group_members_list}
    ${members}=    Get From Dictionary    ${dict}    members
    FOR    ${member}    IN    @{members}
        ${group_ip_address}=    Get From Dictionary    ${member}    group_ip_address
        Run Keyword If    '${group_ip_address}' == '${group}'
        ...    Append To List    ${group_members_list}    ${member}
    END
    [Return]    ${group_members_list}

Verify Members in Igmp Group Count
    [Documentation]    Verifies the given IGMP group has certain entries/count
    [Arguments]    ${igmpca_rel_session}    ${total_members}    ${group}
    @{group_members_list}=    Get Igmp Group Members List    ${igmpca_rel_session}    ${group}
    ${total_group_members}=    Get Length    ${group_members_list}
    Should Be Equal As Integers     ${total_group_members}    ${total_members}

Verify Empty Igmp Group
    [Documentation]    Verifies the given IGMP group has no members
    [Arguments]    ${igmpca_rel_session}    ${group}
    @{group_members_list}=    Get Igmp Group Members List    ${igmpca_rel_session}    ${group}
    Should Be Empty     ${group_members_list}