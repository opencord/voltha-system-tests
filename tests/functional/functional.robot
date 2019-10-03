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
Documentation     Creates bbsim olt/onus and validates activation
...               Assumes voltha-go, go-based onu/olt adapters, and bbsim are installed
...               voltctl and kubectl should be configured prior to running these tests
Library           OperatingSystem
Resource          ./../../libraries/onos.robot
Resource          ./../../libraries/voltctl.robot
Resource          ./../../libraries/utils.robot
Resource          ./../../variables/variables.robot
Suite Setup       Setup
Suite Teardown    Teardown

*** Variables ***
${server_ip}        localhost
${timeout}          420s
${SADIS_FILE}       ${CURDIR}/../data/sadis-with-tp.json
${BBSIM_OLT_SN}     ${EMPTY}
${num_onus}         16

*** Test Cases ***
Activate Device BBSIM OLT/ONU
    [Documentation]    Validate deployment ->
    ...    create and enable bbsim device ->
    ...    re-validate deployment
    [Tags]    Functional
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${BBSIM_IP}    ${BBSIM_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    60s    5s    Validate OLT Device   PREPROVISIONED    UNKNOWN    UNKNOWN  ${EMPTY}    ${olt_device_id}
    #enable device
    Enable Device    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    60s    5s    Validate OLT Device   ENABLED    ACTIVE    REACHABLE    ${BBSIM_OLT_SN}
    #validate onu states
    Wait Until Keyword Succeeds    ${timeout}    20s    Validate ONU Devices    ${List_ONU_Serial}    ENABLED    ACTIVE    REACHABLE

Validate Device's Ports and Flows
    [Documentation]  Verify Ports and Flows listed for OLT and ONUs
    ...     For OLT we validate the port types and numbers and for flows we simply verify that their numbers > 0
    ...     For each ONU, we validate the port types and numbers for each and for flows. For flows they should be == 0 at this stage
    [Tags]  Functional
    #validate olt port types
    Validate OLT Port Types     PON_OLT     ETHERNET_NNI
    #validate olt flows
    Validate OLT Flows
    #validate onu port types
    Validate ONU Port Types     ${List_ONU_Serial}    PON_ONU     ETHERNET_UNI
    #validate onu flows
    Validate ONU Flows      ${List_ONU_Serial}      ZERO

Validate Logical Device
    [Documentation]  Verify that logical device exists and then verify its ports and flows
    [Tags]  Functional
    #Verify logical device exists
    ${logical_device_id}=   Validate Logical Device
    #Verify logical device ports
    Validate Logical Device Ports   ${logical_device_id}
    #Verify logical device flows
    Validate Logical Device Flows   ${logical_device_id}

*** Keywords ***
Setup
    [Documentation]    Setup environment
    Log    Setting up
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    Check CLI Tools Configured
    ${ONOS_AUTH}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${server_ip}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    ${List_ONU_Serial}  Create List
    Set Suite Variable  ${List_ONU_Serial}
    Parse Sadis File    ${List_ONU_Serial}
    Send File To Onos  ${SADIS_FILE}  apps/
    Log To Console  \nOLT_Serial=${BBSIM_OLT_SN}
    Log To Console  \nONU_Serial_List=${List_ONU_Serial}

Teardown
    [Documentation]    Delete all http sessions
    Delete All Sessions

Parse Sadis File
    [Documentation]  Read and Parse Sadis file to determine serial numbers of OLT/ONUs
    [Arguments]  ${List_ONU_Serial}
    Read Sadis File     ${SADIS_FILE}    ${BBSIM_OLT_SN}    ${List_ONU_Serial}
    Set Global Variable  ${BBSIM_OLT_SN}
