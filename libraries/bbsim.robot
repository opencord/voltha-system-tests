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
    ${onus}=    Exec Pod    ${namespace}    ${bbsim_pod_name}   bbsimctl onu list
    Log     ${onus}

Restart Auth
    [Documentation]  Restart Authentication on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}   bbsimctl onu auth_restart ${onu}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Restart DHCP
    [Documentation]  Restart Authentication on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}   bbsimctl onu dhcp_restart ${onu}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0
