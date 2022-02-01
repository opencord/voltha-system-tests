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

*** Variables ***
&{IGMP_TASK_DICT}          join=0    leave=1    joinv3=2

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

JoinOrLeave Igmp Rest Based
    [Documentation]  Joins or Leaves Igmp on a BBSim ONU (based on Rest Endpoint)
    [Arguments]    ${bbsim_rel_session}    ${onu}    ${task}    ${group_address}
    ${resp}=    Post Request    ${bbsim_rel_session}
    ...    /v1/olt/onus/${onu}/igmp/${IGMP_TASK_DICT}[${task}]/${group_address}
    Log    ${resp}

JoinOrLeave Igmp
    [Documentation]  Joins or Leaves Igmp on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}    ${task}    ${group_address}=224.0.0.22
    ${res}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu igmp ${onu} ${task} ${group_address}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Power On ONU
    [Documentation]    This keyword turns on the power for onu device.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${result}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu poweron ${onu}
    Should Contain    ${result}    successfully    msg=Can not poweron ${onu}    values=False

Power Off ONU
    [Documentation]    This keyword turns off the power for onu device.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${result}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu shutdown ${onu}
    Should Contain    ${result}    successfully    msg=Can not shutdown ${onu}    values=False

Set Wrong MDS Counter ONU
    [Documentation]    This keyword sets wrong MDS counter for onu device.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${result}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu invalidate_mds ${onu}
    Should Be Equal as Integers    ${rc}    0
    Should Contain    ${result}    MDS counter of ONU    msg=Can not invalidate MDS counter ${onu}    values=False
    Should Contain    ${result}    , set to    msg=Can not invalidate MDS counter ${onu}    values=False

Get ONUs List
    [Documentation]    Fetches ONUs via BBSimctl
    [Arguments]    ${namespace}    ${bbsim_pod_name}
    ${onus}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu list | awk 'NR>1 {print $3}'
    @{onuList}=    Split To Lines    ${onus}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${onuList}

Restart Grpc Server
    [Documentation]  Restart Grpc Server on a BBSim OLT
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${delay}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl olt restartServer ${delay}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Verify ONU Device Image On BBSim
    [Documentation]    Validates the state of ONU in case of Image Upgrade
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}    ${internal_state}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu list | grep ${onu} | awk '{print $5}'
    Should Be Equal as Integers    ${rc}    0
    Should Be Equal    ${res}    ${internal_state}

Get Images Count
    [Documentation]    Validates the state of ONU in case of Image Upgrade
    [Arguments]    ${webserver_port}=50074
    ${rc}    ${output}=    Run and Return Rc and Output    curl localhost:${webserver_port}/images-count 2>/dev/null
    Should Be Equal as Integers    ${rc}    0    Could not access images-count of bbsim
    ${value}=    Fetch From Right    ${output}    :
    ${count}=    Fetch From Left     ${value}    }
    [Return]    ${count}
