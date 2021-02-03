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
Documentation     Library for BBSimCtl interactions
Resource          ./k8s.robot

*** Keywords ***
List ONUs
    [Documentation]  Lists ONUs via BBSimctl
    [Arguments]    ${namespace}    ${bbsim_pod_name}
    ${onus}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu list
    Log     ${onus}
    Should Be Equal as Integers    ${rc}    0

Restart Auth
    [Documentation]  Restart Authentication on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu auth_restart ${onu}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Restart DHCP
    [Documentation]  Restart Dhcp on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu dhcp_restart ${onu}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

List Service
    [Documentation]  Lists Service via BBSimctl
    [Arguments]    ${namespace}    ${bbsim_pod_name}
    ${service}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl service list
    Log     ${service}
    Should Be Equal as Integers    ${rc}    0

JoinOrLeave Igmp
    [Documentation]  Joins or Leaves Igmp on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}    ${task}    ${group_address}=224.0.0.22
    ${res}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu igmp ${onu} ${task} ${group_address}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Get ONUs List
    [Documentation]    Fetches ONUs via BBSimctl
    [Arguments]    ${namespace}    ${bbsim_pod_name}
    ${onus}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu list | awk 'NR>1 {print $4}'
    @{onuList}=    Split To Lines    ${onus}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${onuList}
