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
Documentation     Creates bbsim olt/onu and validates activataion
...               Assumes voltha-go, go-based onu/olt adapters, and bbsim are installed
...               voltctl and kubectl should be configured prior to running these tests
Suite Setup       Setup
Suite Teardown    Teardown
Test Teardown     Execute ONOS CLI Command    ${server_ip}    ${ONOS_SSH_PORT}    flows -s
Library           OperatingSystem
Resource          ${CURDIR}/../../libraries/onos.robot
Resource          ${CURDIR}/../../libraries/voltctl.robot
Resource          ${CURDIR}/../../libraries/utils.robot
Resource          ${CURDIR}/../../variables/variables.robot

*** Variables ***
${server_ip}      localhost
${timeout}        90s
${num_onus}       1

*** Test Cases ***
Activate Device BBSIM OLT/ONU
    [Documentation]    Validate deployment ->
    ...    create and enable bbsim device ->
    ...    re-validate deployment
    [Tags]    sanity
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${BBSIM_IP}    ${BBSIM_PORT}
    Set Suite Variable    ${olt_device_id}
    #enable device
    Enable Device    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    60s    5s    Validate Device    ${BBSIM_OLT_SN}    ENABLED    ACTIVE
    ...    REACHABLE
    #validate onu states
    Wait Until Keyword Succeeds    60s    5s    Validate Device    ${BBSIM_ONU_SN}    ENABLED    ACTIVE
    ...    REACHABLE    onu=True    onu_reason=tech-profile-config-download-success
    #get onu device id
    ${onu_device_id}=    Get Device ID From SN    ${BBSIM_ONU_SN}
    Set Suite Variable    ${onu_device_id}

Validate OLT Connected to ONOS
    [Documentation]    Verifies the BBSIM-OLT device is activated in onos
    [Tags]    sanity
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device in ONOS    ${BBSIM_OLT_SN}
    Set Suite Variable    ${of_id}

Check EAPOL Flows in ONOS
    [Documentation]    Validates eapol flows for the onu are pushed from voltha
    [Tags]    sanity
    ${num_flows}=    Evaluate    ${num_onus} * 4
    ${flows_str}=    Convert To String    ${num_flows}
    Wait Until Keyword Succeeds    ${timeout}    5s    Verify Eapol Flows Added    ${server_ip}    ${ONOS_SSH_PORT}    ${flows_str}

Validate ONU Authenticated in ONOS
    [Documentation]    Validates onu is AUTHORIZED in ONOS as bbsim will attempt to authenticate
    [Tags]    sanity
    Wait Until Keyword Succeeds    ${timeout}    1s    Verify Number of AAA-Users    ${server_ip}    ${ONOS_SSH_PORT}    ${num_onus}

Add Subscriber-Access in ONOS
    [Documentation]    Through the olt-app in ONOS, execute 'volt-add-subscriber-access' and validate IP Flows
    [Tags]    sanity
    ##    TODO: this works fine with 1 onu, but with multiple onus, we need to ensure this is executes
    ##    prior to to dhclient starting. possible start a process after first test case to just attempt
    ##    "volt-add-subscriber-access" to all onus periodically?
    ${output}=    Execute ONOS CLI Command    ${server_ip}    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} 16
    Log    ${output}

Validate DHCP Assignment in ONOS
    [Documentation]    After IP Flows are pushed to the device, BBSIM will start a dhclient for the ONU.
    [Tags]    sanity
    Wait Until Keyword Succeeds    120s    15s    Validate DHCP Allocations    ${server_ip}    ${ONOS_SSH_PORT}    ${num_onus}

Delete Device and Verify
    [Documentation]    Disable -> Delete devices via voltctl and verify its removed
    [Tags]    sanity
    #disable/delete onu
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${onu_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    60s    5s    Validate Device    ${BBSIM_ONU_SN}    DISABLED    UNKNOWN
    ...    REACHABLE
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${onu_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    60s    5s    Validate Device Removed    ${onu_device_id}
    #disable/delete olt
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    60s    5s    Validate Device    ${BBSIM_OLT_SN}    DISABLED    UNKNOWN
    ...    REACHABLE
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    60s    5s    Validate Device Removed    ${olt_device_id}

*** Keywords ***
Setup
    [Documentation]    Setup environment
    Log    Setting up
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    Check CLI Tools Configured
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${server_ip}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}

Teardown
    [Documentation]    Delete all http sessions
    Delete All Sessions
