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
# onos common functions

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
Calculate flows by workflow
    [Documentation]  Calculate how many flows should be created based on the workflow, the number of UNIs
    ...     and whether the subscribers have been provisioned
    [Arguments]  ${workflow}    ${uni_count}    ${olt_count}    ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}
    ${expectedFlows}=   Run Keyword If  $workflow=="att"  Calculate Att flows
    ...     ${uni_count}    ${olt_count}    ${provisioned}  ${withEapol}    ${withDhcp}     ${withIgmp}
    ...     ELSE IF     $workflow=="dt"     Calculate Dt Flows
    ...     ${uni_count}    ${olt_count}    ${provisioned}
    ...     ELSE IF     $workflow=="tt"     Calculate Tt Flows
    ...     ${uni_count}    ${olt_count}    ${provisioned}  ${withDhcp}     ${withIgmp}
    ...     ELSE    Fail    Workflow ${workflow} should be one of 'att', 'dt', 'tt'
    Return From Keyword     ${expectedFlows}

Calculate Att flows
    [Documentation]  Calculate the flow for the ATT workflow
    ...     NOTE we may need to add support for IGMP enabled/disabled
    [Arguments]  ${uni_count}    ${olt_count}   ${provisioned}      ${withEapol}    ${withDhcp}     ${withIgmp}
    # (1 EAPOL * ONUs) * (1 LLDP + 1 DHCP * OLTS) before provisioning
    # (1 EAPOL, 1 DHCP, 1 IGMP, 4 DP * ONUs) * (1 LLDP + 1 DHCP * OLTS) after provisioning
    ${eapFlowsCount}=   Run Keyword If   $withEapol=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${dhcpFlowsCount}=   Run Keyword If   $withDhcp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${igmpFlowsCount}=   Run Keyword If   $withIgmp=='true'
    ...     Evaluate     2
    ...     ELSE
    ...     Evaluate     0
    ${flow_count}=  Run Keyword If  $provisioned=='false'
    ...     Evaluate    (${uni_count} * ${eapFlowsCount}) + (${olt_count} * 2)
    ...     ELSE
    ...     Calculate Att Provisione Flows  ${olt_count}    ${uni_count}
    ...     ${eapFlowsCount}   ${dhcpFlowsCount}   ${igmpFlowsCount}
    Return From Keyword     ${flow_count}

Calculate Att Provisione Flows
    [Documentation]  This calculate the flows for provisioned subscribers in the ATT workflow
    [Arguments]  ${olt_count}   ${uni_count}    ${eapFlowsCount}   ${dhcpFlowsCount}   ${igmpFlowsCount}
    ${eap}=     Evaluate    ${uni_count} * ${eapFlowsCount}
    ${dhcp}=    Evaluate    ${uni_count} * ${dhcpFlowsCount}
    ${igmp}=    Evaluate    ${uni_count} * ${igmpFlowsCount}
    ${dataplane}=   Evaluate    ${uni_count} * 4
    ${nni}=     Evaluate    ${olt_count} * 2
    ${total}=   Evaluate    ${eap} + ${dhcp} + ${igmp} + ${dataplane} + ${nni}
    Return From Keyword     ${total}

Calculate Dt flows
    [Documentation]  Calculate the flow for the DT workflow
    [Arguments]  ${uni_count}    ${olt_count}   ${provisioned}
    # (1 LLDP * OLTS) before provisioning
    # (4 DP * ONUs) * (1 LLDP * OLTS) after provisioning
    ${flow_count}=  Run Keyword If  $provisioned=='false'
        ...     Evaluate    (${olt_count} * 1)
        ...     ELSE
        ...     Evaluate    (${uni_count} * 4) + (${olt_count} * 1)
    Return From Keyword     ${flow_count}

Calculate Tt flows
    [Documentation]  Calculate the flow for the TT workflow
    [Arguments]  ${uni_count}    ${olt_count}   ${provisioned}  ${withDhcp}     ${withIgmp}
    # TODO account for withDhcp, withIgmp, see Calculate Att flows for examples
    # (1 LLDP + 1 DHCP * OLTS) before provisioning
    # (1 DHCP, 1 IGMP, 4 DP * ONUs) * (1 LLDP + 1 DHCP * OLTS) after provisioning
    ${flow_count}=  Run Keyword If  $provisioned=='false'
        ...     Evaluate    (${olt_count} * 2)
        ...     ELSE
        ...     Evaluate    (${uni_count} * 6) + (${olt_count} * 1)
    Return From Keyword     ${flow_count}