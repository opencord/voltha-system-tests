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
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLldp}
    ${expectedFlows}=   Run Keyword If  $workflow=="att"  Calculate Att flows
    ...     ${uni_count}    ${olt_count}    ${provisioned}  ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    ...     ELSE IF     $workflow=="dt"     Calculate Dt Flows
    ...     ${uni_count}    ${olt_count}    ${provisioned}  ${withLldp}
    ...     ELSE IF     $workflow=="tt"     Calculate Tt Flows
    ...     ${uni_count}    ${olt_count}    ${provisioned}  ${withDhcp}     ${withIgmp}     ${withLldp}
    ...     ELSE IF     $workflow=="tim"     Calculate Tim Flows
    ...     ${uni_count}    ${olt_count}    ${provisioned}  ${withPppoe}     ${withIgmp}     ${withLldp}
    ...     ELSE    Fail    Workflow ${workflow} should be one of 'att', 'dt', 'tt' , 'tim'
    Return From Keyword     ${expectedFlows}

Calculate Att flows
    [Documentation]  Calculate the flow for the ATT workflow
    ...     NOTE we may need to add support for IGMP enabled/disabled
    [Arguments]  ${uni_count}    ${olt_count}   ${provisioned}      ${withEapol}    ${withDhcp}
    ...     ${withIgmp}    ${withLldp}
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
    ${lldpFlowsCount}=   Run Keyword If   $withLldp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${flow_count}=  Run Keyword If  $provisioned=='false'
    ...     Calculate Att Preprovisioned Flows   ${olt_count}    ${uni_count}
    ...     ${eapFlowsCount}   ${dhcpFlowsCount}   ${igmpFlowsCount}    ${lldpFlowsCount}
    ...     ELSE
    ...     Calculate Att Provisioned Flows  ${olt_count}    ${uni_count}
    ...     ${eapFlowsCount}   ${dhcpFlowsCount}   ${igmpFlowsCount}    ${lldpFlowsCount}
    Return From Keyword     ${flow_count}

Calculate Att Preprovisioned Flows
    [Documentation]  This calcualtes the flows before subscribers are provisioned in the ATT workflow
    [Arguments]  ${olt_count}   ${uni_count}    ${eapFlowsCount}   ${dhcpFlowsCount}
    ...    ${igmpFlowsCount}   ${lldpFlowsCount}
    ${eap}=     Evaluate    ${uni_count} * ${eapFlowsCount}
    ${nni}=     Evaluate    (${olt_count} * ${dhcpFlowsCount}) + (${olt_count} * ${lldpFlowsCount})
    ${total}=   Evaluate    ${eap} + ${nni}
    Return From Keyword     ${total}

Calculate Att Provisioned Flows
    [Documentation]  This calculates the flows for provisioned subscribers in the ATT workflow
    [Arguments]  ${olt_count}   ${uni_count}    ${eapFlowsCount}   ${dhcpFlowsCount}
    ...    ${igmpFlowsCount}   ${lldpFlowsCount}
    ${eap}=     Evaluate    ${uni_count} * ${eapFlowsCount}
    ${dhcp}=    Evaluate    ${uni_count} * ${dhcpFlowsCount}
    ${igmp}=    Evaluate    ${uni_count} * ${igmpFlowsCount}
    ${dataplane}=   Evaluate    ${uni_count} * 4
    ${nni}=     Evaluate    (${olt_count} * ${dhcpFlowsCount}) + (${olt_count} * ${lldpFlowsCount})
    ${total}=   Evaluate    ${eap} + ${dhcp} + ${igmp} + ${dataplane} + ${nni}
    Return From Keyword     ${total}

Calculate Dt flows
    [Documentation]  Calculate the flow for the DT workflow
    [Arguments]  ${uni_count}    ${olt_count}   ${provisioned}   ${withLldp}
    # (1 LLDP * OLTS) before provisioning
    # (4 DP * ONUs) * (1 LLDP * OLTS) after provisioning
    ${lldpFlowsCount}=   Run Keyword If   $withLldp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${flow_count}=  Run Keyword If  $provisioned=='false'
        ...     Evaluate    (${olt_count} * ${lldpFlowsCount})
        ...     ELSE
        ...     Evaluate    (${uni_count} * 4) + (${olt_count} * ${lldpFlowsCount})
    Return From Keyword     ${flow_count}

Calculate Tt flows
    [Documentation]  Calculate the flow for the TT workflow
    [Arguments]  ${uni_count}    ${olt_count}   ${provisioned}  ${withDhcp}     ${withIgmp}    ${withLldp}
    # TODO account for withDhcp, withIgmp, see Calculate Att flows for examples
    # (1 LLDP + 1 DHCP + 1 IGMP * OLTS) before provisioning
    # (1 DHCP, 1 IGMP, 4 DP * ONUs) * (1 LLDP + 1 DHCP + 1 IGMP * OLTS) after provisioning
    ${dhcpFlowsCount}=   Run Keyword If   $withDhcp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${lldpFlowsCount}=   Run Keyword If   $withLldp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${igmpFlowsCount}=   Run Keyword If   $withIgmp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${totalDhcpFlows}=   Evaluate   ${olt_count} * ${dhcpFlowsCount}
    ${totalLldpFlows}=   Evaluate   ${olt_count} * ${lldpFlowsCount}
    ${totalIgmpFlows}=   Evaluate   ${olt_count} * ${igmpFlowsCount}
    ${flow_count}=  Run Keyword If  $provisioned=='false'
    ...     Evaluate     ${totalDhcpFlows} + ${totalLldpFlows} + ${totalIgmpFlows}
    ...     ELSE
    ...     Evaluate    (${uni_count} * 15) + ${totalDhcpFlows} + ${totalLldpFlows} + ${totalIgmpFlows}
    Return From Keyword     ${flow_count}

Calculate Tim flows
    [Documentation]  Calculate the number of flow rules for the Tim workflow in a single OLT,
    ...     at the variation of the number of ONis provisioned
    ...     Case 1: ( 1 LLDP + 1 PPPoE + 1 IGMP) for each OLTs before provisioning
    ...     Case 2: ( 2 Any VLAN) + ( UNIs * 8 ) + (1 LLDP + 1 PPPoE + 1 IGMP) for each OLTs after provisioning
    [Arguments]  ${uni_count}    ${olt_count}   ${provisioned}  ${withPppoe}     ${withIgmp}    ${withLldp}

    #Define the any Vlan Number Flows in a OLT after the subscription of almost one subscriber
    #One Any Vlan roule for each service ( HSIA , VoD )
    ${anyVlanFlowsCount}=   Evaluate    2

    #Define the number of flows for single UNIs where there are a subscriber
    # 4 Flow Rules for HSIA Service and 4 Flow Rules for VoD Service
    ${uniUpDownFlowsCount}=   Evaluate    8

    ${pppoeFlowsCount}=   Run Keyword If   $withPppoe=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${lldpFlowsCount}=   Run Keyword If   $withLldp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${igmpFlowsCount}=   Run Keyword If   $withIgmp=='true'
    ...     Evaluate     1
    ...     ELSE
    ...     Evaluate     0
    ${pppoeFlowsCount}=   Evaluate   ${olt_count} * ${pppoeFlowsCount}
    ${totalLldpFlows}=   Evaluate   ${olt_count} * ${lldpFlowsCount}
    ${totalIgmpFlows}=   Evaluate   ${olt_count} * ${igmpFlowsCount}
    ${totalPppoeLlldpIgmpFlows}=    Evaluate    ${pppoeFlowsCount} + ${totalLldpFlows} + ${totalIgmpFlows}
    ${flow_count}=  Run Keyword If  $provisioned=='false'
    ...     Set Variable    ${totalPppoeLlldpIgmpFlows}
    ...     ELSE
    ...     Evaluate    ${anyVlanFlowsCount} + (${uniUpDownFlowsCount} * ${uni_count}) + ${totalPppoeLlldpIgmpFlows}
    Return From Keyword     ${flow_count}