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
Library           BuiltIn
Library           Collections
Library           String
Library           RequestsLibrary

*** Keywords ***

Assert Olt in LWC
    [Arguments]    ${deviceId}
    [Documentation]    Check that a particular olt is known to ONOS
    ${output}=  Exec Pod    infra    lwc    ./lwcctl device
    Log     Logical device id: ${deviceId}
    Should Contain  ${output}   ${deviceId}     msg="LWC device command does not contain logical device id"

Wait for Olt in LWC
    [Arguments]    ${deviceId}   ${max_wait_time}=10m
    [Documentation]    Waits until a particular deviceId is recognized by LWC as an OLT
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Olt in LWC
    ...     ${deviceId}

Wait for Olts in LWC
    [Arguments]     ${count}
    Wait for Logical Devices to be in VOLTHA    ${count}
    ${devices}=    Get Logical Device List from Voltha
     FOR     ${device}     IN  @{devices}
        ${id}=   Get From Dictionary     ${device}   id
        Wait for Olt in LWC  ${id}
    END

Assert Ports in LWC
    [Arguments]    ${count}
    [Documentation]    Check that a certain number of ports are enabled in LWC
    ${ports}=    Exec Pod    infra    lwc
    ...    ./lwcctl port | grep BBSM | grep UP | wc -l
    Log     Found ${ports} of ${count} expected ports
    Should Be Equal As Integers    ${ports}    ${count}

Wait for Ports in LWC
    [Arguments]    ${count}    ${max_wait_time}=10m
    [Documentation]    Waits untill a certain number of ports are enabled in LWC for a particular deviceId
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Ports in LWC
    ...     ${count}

Validate number of flows in LWC
    [Arguments]  ${targetFlows}
    ${flows}=    Exec Pod    infra    lwc
    ...    ./lwcctl flows | grep -v Cookie | grep -v "\\-\\-\\-\\-\\-" | grep -v KV | wc -l
    Log     Found ${flows} of ${targetFlows} expected flows
    Should Be Equal As Integers    ${targetFlows}    ${flows}

Wait for flows in LWC
    [Documentation]  Waits until the flows have been provisioned
    [Arguments]  ${workflow}    ${uni_count}    ${olt_count}
    ...    ${provisioned}     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    ${targetFlows}=     Calculate flows by workflow     ${workflow}    ${uni_count}    ${olt_count}     ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    Wait Until Keyword Succeeds     10m     5s      Validate number of flows in LWC
    ...     ${targetFlows}

List all ONUs
    # once we test with multiple UNIs this will have to be updated
    ${rc1}    ${devices}=    Run and Return Rc and Output
    ...   voltctl -c ${VOLTCTL_CONFIG} device list -m ${voltctlGrpcLimit} -f Type=brcm_openomci_onu -o json
    Log    ${devices}
    Should Be Equal As Integers    ${rc1}    0
    ${onus}=    Evaluate    json.loads(r'''${devices}''')    json
    ${num_onus}=    Get Length  ${onus}
    ${onus_list}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${num_onus}
        ${onu_sn}=  Set Variable    ${onus[${INDEX}]['serialNumber']}
        ${onu_idx}=    Get Index From List    ${onus_list}   ${onu_sn}
        Continue For Loop If    -1 != ${onu_idx}
        Append To List    ${onus_list}    ${onu_sn}
    END
    [Return]    ${onus_list}

Create BP for Subscriber in LWC
    [Documentation]     Creates the Bandwidth Profile for a specific subscriber in LWC
    [Arguments]     ${base_url}     ${sub_id}
    ${body}=    Create Dictionary    id=hsia    gir=${50000}
    ...     cbs=${10000}   cir=${50000}   pbs=${1000}    pir=${300000}
    log dictionary  ${body}
    ${id}=  Catenate    SEPARATOR=  s   ${sub_id}
    ${resp}=    POST    http://${base_url}/profiles/${id}    json=${body}
    Status Should Be    OK    ${resp}

Provision Subscriber in LWC
    [Documentation]     Creates the Subscriber in LWC (only works for DT)
    [Arguments]     ${base_url}     ${sub_id}   ${uni}
    ${sTag}=    Evaluate    ${2} + ${sub_id}
    ${uniTag}=  Create Dictionary   uniTagMatch=${4096}     ponCTag=${4096}
    ...     ponSTag=${sTag}     technologyProfileId=${64}   downstreamBandwidthProfile=hsia
    ...     upstreamBandwidthProfile=hsia
    ${uniTagList}=  Create List     ${uniTag}

    ${id}=  Catenate    SEPARATOR=  s   ${sub_id}
    ${body}=    Create Dictionary    id=${id}    nasPortId=${uni}
    ...     uniTagList=${uniTagList}
    log dictionary  ${body}
    ${resp}=    POST    http://${base_url}/subscribers/${id}    json=${body}
    Status Should Be    OK    ${resp}

Provision all subscribers on LWC
    [Arguments]     ${base_url}
    ${onus}=    List all ONUs
    Log     ${onus}
    ${onu_count}=   Get Length  ${onus}
    FOR     ${idx}   IN RANGE   0   ${onu_count}
        ${sn}=  get from list   ${onus}     ${idx}
        Log     ${sn}
        Create BP for Subscriber in LWC     ${base_url}     ${idx}
        ${uni}=     Catenate    SEPARATOR=-     ${sn}   1
        Provision Subscriber in LWC     ${base_url}     ${idx}  ${uni}
    END
