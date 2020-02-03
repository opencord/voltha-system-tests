#Copyright 2017-present Open Networking Foundation
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
Documentation     This test raises alarms using bbsimctl and verifies them using voltctl
Suite Setup       Setup Suite
#Suite Teardown    Teardown Suite
Library           Collections
Library           String
Library           OperatingSystem
Library           XML
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot

*** Variables ***
${timeout}        60s
${long_timeout}    420s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    False
${VOLTCTL_NAMESPACE}      default
${BBSIMCTL_NAMESPACE}      voltha
${VOLTCTL_POD_NAME}    voltctl
${BBSIMCTL_POD_NAME}    bbsim

*** Test Cases ***
Ensure required pods Running
    Validate Pod Status    ${BBSIMCTL_POD_NAME}    ${BBSIMCTL_NAMESPACE}    Running
    Validate Pod Status    ${VOLTCTL_POD_NAME}    ${VOLTCTL_NAMESPACE}     Running

Activate Devices OLT/ONU
    [Documentation]    Validate deployment -> Empty Device List
    ...    create and enable device -> Preprovision and Enable
    ...    re-validate deployment -> Active OLT
    [Tags]    active    deploy_devices
    #test for empty device list
    Test Empty Device List
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Global Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${EMPTY}    ${olt_device_id}
    #enable device
    Enable Device    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${EMPTY}    ${olt_device_id}

ONU Discovery
    [Documentation]    Discover lists of ONUS, their Serial Numbers and device id, and pick one for subsequent tests
    [Tags]    active
    #build onu sn list
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Log    ${List_ONU_Serial}
    #validate onu states
    Wait Until Keyword Succeeds    ${long_timeout}    20s
    ...    Validate ONU Devices    ENABLED    ACTIVE    REACHABLE    ${List_ONU_Serial}
    # Pick an ONU to use for subsequent test cases
    ${onu_sn}    Set Variable    ${List_ONU_Serial}[0]
    Set Suite Variable    ${onu_sn}
    ${onu_id}    Get Device ID From SN    ${onu_sn}
    Set Suite Variable    ${onu_id}

Test StartupFailureAlarm
    [Tags]    active
    Raise Alarm    StartupFailure    ${onu_sn}
    # This one is actually broken...
    # TODO: complete test once alarm is working...

Test RaiseLossOfBurstAlarm
    [Documentation]    Raise Loss Of Burst Alarm
    [Tags]    active
    ${since}    Get Current Time
    Raise Alarm    LossOfBurst    ${onu_sn}
    ${header}    ${deviceEvent}    Get Device Event    ONU_LOSS_OF_BURST_RAISE_EVENT    ${since}
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_BURST\.(\\d+)
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_BURST_RAISE_EVENT
    # TODO: Why does the event have the OLT ID instead of the ONU ID ? Verify correctness.
    ${parent_id}    Get Parent ID From Device ID     ${onu_id}
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLossOfBurstAlarm
    [Documentation]    Clear Loss Of Burst Alarm
    [Tags]    active
    ${since}    Get Current Time
    Clear Alarm    LossOfBurst    ${onu_sn}
    ${header}    ${deviceEvent}    Get Device Event    ONU_LOSS_OF_BURST_CLEAR_EVENT    ${since}
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_BURST\.(\\d+)
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_BURST_CLEAR_EVENT
    # TODO: Why does the event have the OLT ID instead of the ONU ID ? Verify correctness.
    ${parent_id}    Get Parent ID From Device ID     ${onu_id}
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    # Ensure the voltctl pod is deployed and running
    Apply Kubernetes Resources    ./voltctl.yaml    ${VOLTCTL_NAMESPACE}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Pod Status    ${VOLTCTL_POD_NAME}    ${VOLTCTL_NAMESPACE}     Running

Teardown Suite
    [Documentation]    Clean up devices if desired
    ...    kills processes and cleans up interfaces on src+dst servers
    Run Keyword If    ${external_libs}    Get ONOS Status    ${k8s_node_ip}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${external_libs}
    ...    Log Kubernetes Containers Logs Since Time    ${datetime}    ${container_list}
    Run Keyword If    ${teardown_device}    Delete Device and Verify
    Run Keyword If    ${teardown_device}    Test Empty Device List
    Run Keyword If    ${teardown_device}    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
    ...    device-remove ${of_id}

Should Be Larger Than
    [Arguments]    ${value_1}    ${value_2}
    Run Keyword If    ${value_1} <= ${value_2}    
    ...    Fail    The value ${value_1} is not larger than ${value_2}

Should Be Float
    [Arguments]    ${value}
    ${type}    Evaluate    type(${value}).__name__
    Should Be Equal    ${type}    float

Raise Alarm
    [Documentation]    Raise an Alarm
    [Arguments]    ${name}    ${sn}
    ${raiseOutput}    Exec Pod    ${BBSIMCTL_NAMESPACE}     ${BBSIMCTL_POD_NAME}    bbsimctl alarm raise ${name} ${sn}
    Should Contain    ${raiseOutput}    Alarm Indication Sent

Clear Alarm
    [Documentation]    Raise an Alarm
    [Arguments]    ${name}    ${sn}
    ${raiseOutput}    Exec Pod    ${BBSIMCTL_NAMESPACE}     ${BBSIMCTL_POD_NAME}    bbsimctl alarm clear ${name} ${sn}
    Should Contain    ${raiseOutput}    Alarm Indication Sent

Get Device Event
    [Documentation]    Get the most recent alarm event from voltha.events
    [Arguments]    ${deviceEventName}    ${since}
    ${output}    ${raiseErr}    Exec Pod Separate Stderr   ${VOLTCTL_NAMESPACE}     ${VOLTCTL_POD_NAME}    voltctl event listen --show-body -t 1 -o json -f Titles=${deviceEventName} -s ${since}
    ${json}    To Json    ${output}
    ${count}    Get Length    ${json}
    # If there is more than one event (which could happen if we quickly do a raise and a clear),
    # then return the most recent one.
    Should Be Larger Than   ${count}    0
    ${lastIndex}    Evaluate    ${count}-1
    ${lastItem}    Set Variable    ${json}[${lastIndex}]
    ${header}    Set Variable    ${lastItem}[header]
    ${deviceEvent}    Set Variable   ${lastItem}[deviceEvent] 
    Log    ${header}
    Log    ${deviceEvent}
    [return]    ${header}    ${deviceEvent}

Verify Header
    [Documentation]    Verify that a DeviceEvent's header is sane and the id matches regex
    [Arguments]    ${header}    ${id}
    Should Be Equal   ${header}[subCategory]    ONU
    Should Be Equal   ${header}[type]    DEVICE_EVENT
    Should Match Regexp    ${header}[id]    ${id}
    # TODO Revisit when timestamp format is changed from Float to Timestamp
    Should Be Float   ${header}[raisedTs]
    Should Be Float   ${header}[reportedTs]

Get Current Time
    ${rc}    ${output}=    Run and Return Rc and Output    date --rfc-3339=s | sed 's/ /T/'
    [return]     ${output}

Clean Up Linux
    [Documentation]    Kill processes and clean up interfaces on src+dst servers
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword And Ignore Error    Kill Linux Process    [w]pa_supplicant    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Ignore Error    Kill Linux Process    [d]hclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Run Keyword And Ignore Error
        ...    Kill Linux Process    [d]hcpd    ${dst['ip']}    ${dst['user']}
        ...    ${dst['pass']}    ${dst['container_type']}    ${dst['container_name']}
        Delete IP Addresses from Interface on Remote Host    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Delete Interface on Remote Host
        ...    ${dst['dp_iface_name']}.${src['s_tag']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}
        ...    ${dst['container_type']}    ${dst['container_name']}
    END

Delete Device and Verify
    [Documentation]    Disable -> Delete devices via voltctl and verify its removed
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${long_timeout}    5s    Validate Device Removed    ${olt_device_id}
