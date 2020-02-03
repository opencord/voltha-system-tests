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
${ONU_SN}    BBSM00000005

*** Test Cases ***
Ensure required pods running
    Validate Pod Status    ${BBSIMCTL_POD_NAME}    ${BBSIMCTL_NAMESPACE}    Running
    Validate Pod Status    ${VOLTCTL_POD_NAME}    ${VOLTCTL_NAMESPACE}     Running

Activate Devices OLT/ONU
    [Documentation]    Validate deployment -> Empty Device List
    ...    create and enable device -> Preprovision and Enable
    ...    re-validate deployment -> Active OLT
    [Tags]    active
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
    [Documentation]    Discover lists of ONUS, their Serial Numbers and device id
    [Tags]    active
    #build onu sn list
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Log    ${List_ONU_Serial}
    #validate onu states
    Wait Until Keyword Succeeds    ${long_timeout}    20s
    ...    Validate ONU Devices    ENABLED    ACTIVE    REACHABLE    ${List_ONU_Serial}

Test StartupFailure
    Raise Alarm    StartupFailure    ${ONU_SN}
    # This one is actually broken...

Test LossOfBurst
    ${since}    Get Current Time
    Raise Alarm    LossOfBurst    ${ONU_SN}
    Get Alarm Event    ONU_LOSS_OF_BURST_RAISE_EVENT    ${since}

Try to run a command in voltctl pod
    Exec Pod   ${VOLTCTL_NAMESPACE}    ${VOLTCTL_POD_NAME}    ls

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup

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

Raise Alarm
    [Documentation]    Raise an Alarm
    [Arguments]    ${name}    ${sn}
    ${raiseOutput}    Exec Pod    ${BBSIMCTL_NAMESPACE}     ${BBSIMCTL_POD_NAME}    bbsimctl alarm raise ${name} ${sn}
    Should Contain    ${raiseOutput}    Alarm Indication Sent

Get Alarm Event
    [Documentation]    Get the most recent alarm event from voltha.events
    [Arguments]    ${deviceEventName}    ${since}
    ${raiseOutput}    ${raiseErr}    Exec Pod Separate Stderr   ${VOLTCTL_NAMESPACE}     ${VOLTCTL_POD_NAME}    voltctl event listen --show-body -t 1 -o json -f Titles=${deviceEventName} -s ${since}
    ${raiseJson}    To Json    ${raiseOutput}
    ${count}    Get Length    ${raiseJson}
    Should Be Equal As Numbers   ${count}    1

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
