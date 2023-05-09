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
Get OLT SN from IGMPCA
    [Documentation]    Retrieves the OLT SN from IGMPCA using REST API
    ...    This keyword also verifies that the OLT is reachable
    [Arguments]    ${igmpca_rel_session}
    ${resp}=    Get Request    ${igmpca_rel_session}    /v1/olt
    ${dict}=    Evaluate    json.loads(r'''${resp.content}''')    json
    ${connectstatus}=    Get From Dictionary    ${dict}    connectStatus
    Should Be Equal    ${connectstatus}    REACHABLE
    ${sn}=    Get From Dictionary    ${dict}    serialNumber
    [Return]    ${sn}

Get Igmp Groups List
    [Documentation]    Retrieves the IGMP groups using REST API
    [Arguments]    ${igmpca_rel_session}
    @{groups}=    Create List
    ${resp}=    Get Request    ${igmpca_rel_session}    /v1/groups
    ${dict}=    Evaluate    json.loads(r'''${resp.content}''')    json
    Run Keyword If    "groups" not in "&{dict}"
    ...    Return From Keyword    ${groups}
    ${groups}=    Get From Dictionary    ${dict}    groups
    [Return]    ${groups}

Get Igmp Members List
    [Documentation]    Retrieves the IGMP members using REST API
    [Arguments]    ${igmpca_rel_session}
    @{members}=    Create List
    ${resp}=    Get Request    ${igmpca_rel_session}    /v1/members
    ${dict}=    Evaluate    json.loads(r'''${resp.content}''')    json
    Run Keyword If    "members" not in "&{dict}"
    ...    Return From Keyword    ${members}
    ${members}=    Get From Dictionary    ${dict}    members
    [Return]    ${members}

Get Igmp Group Members List
    [Documentation]    Retrieves the IGMP members in the given group
    [Arguments]    ${igmpca_rel_session}    ${group}
    @{group_members}=    Create List
    ${members}=    Get Igmp Members List    ${igmpca_rel_session}
    FOR    ${member}    IN    @{members}
        ${group_ip_address}=    Get From Dictionary    ${member}    group_ip_address
        Run Keyword If    '${group_ip_address}' == '${group}'
        ...    Append To List    ${group_members}    ${member}
    END
    [Return]    ${group_members}

Verify Members in Igmp Group Count
    [Documentation]    Verifies that the given IGMP group has certain entries/count
    [Arguments]    ${igmpca_rel_session}    ${total_members}    ${group}
    @{group_members_list}=    Get Igmp Group Members List    ${igmpca_rel_session}    ${group}
    ${total_group_members}=    Get Length    ${group_members_list}
    Should Be Equal As Integers     ${total_group_members}    ${total_members}

Verify Empty Igmp Group
    [Documentation]    Verifies that the given IGMP group has no member
    [Arguments]    ${igmpca_rel_session}    ${group}
    @{group_members_list}=    Get Igmp Group Members List    ${igmpca_rel_session}    ${group}
    Should Be Empty     ${group_members_list}

Get Igmp Group Member
    [Documentation]    Retrieves an IGMP group member by the specified ponport, onu id and uni id
    [Arguments]    ${igmpca_rel_session}    ${onu_pon}    ${onu_id}    ${uni_id}    ${group}
    @{group_members_list}=    Get Igmp Group Members List    ${igmpca_rel_session}    ${group}
    FOR    ${member}    IN    @{group_members_list}
        ${m_pon_id}=    Evaluate    $member.get("pon_id", 0)
        ${m_onu_id}=    Evaluate    $member.get("onu_id", 0)
        ${m_uni_id}=    Evaluate    $member.get("uni_id", 0)
        Return From Keyword If
        ...    '${m_pon_id}' == '${onu_pon}' and '${m_onu_id}' == '${onu_id}' and '${m_uni_id}' == '${uni_id}'
        ...     ${member}
    END
    [Return]    None

Verify Member in Igmp Group
    [Documentation]    Verifies that the specified member exists in the given IGMP group
    [Arguments]    ${igmpca_rel_session}    ${onu_pon}    ${onu_id}    ${uni_id}    ${group}
    ${match}=    Get Igmp Group Member    ${igmpca_rel_session}    ${onu_pon}    ${onu_id}    ${uni_id}    ${group}
    Should Not Be Equal    ${match}    None

Verify Member Not in Igmp Group
    [Documentation]    Verifies that the specified member doesn't exist in the given IGMP group
    [Arguments]    ${igmpca_rel_session}    ${onu_pon}    ${onu_id}    ${uni_id}    ${group}
    ${match}=    Get Igmp Group Member    ${igmpca_rel_session}    ${onu_pon}    ${onu_id}    ${uni_id}    ${group}
    Should Be Equal    ${match}    None