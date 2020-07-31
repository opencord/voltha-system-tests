# Copyright 2017 - present Open Networking Foundation
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

# Tests can be enabled by passing the following tags:
# - [setup] Creates and enable the OLT devices
# - [activation] Checks that ONUs are active in VOLTHA and ports discevered in ONOS
# - [flow-before] Checks that flows are pushed (before subscriber provisioning)
# - [authentication] Checks that subscribers are correctly authenticated
# - [provision] Provision the data-plane flows for all the subscribers
# - [flow-after] Checks that flows are pushed (after subscriber provisioning)
# - [dhcp] Checks that subscribers have received an IP
#
# To run the full test:
#   robot Voltha_Scale_Tests.robot
#
# To run only ceratain tests:
#   robot -i activation -i flow-before Voltha_Scale_Tests.robot
#
# To exclude only ceratain tests:
#   robot -e -i flow-before Voltha_Scale_Tests.robot
#
# Once te test complete you can extrapolate the results by using
#   python extract-times.py

*** Settings ***
Documentation     Collect measurements on VOLTHA performances
Suite Setup       Setup Suite
#Test Setup        Setup
#Test Teardown     Teardown
Suite Teardown    Teardown Suite
Library           Collections
Library           String
Library           OperatingSystem
Library           XML
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/voltha.robot
Resource          ../../libraries/flows.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot

*** Variables ***
${ONOS_SSH_IP}  127.0.0.1
${ONOS_SSH_PORT}    8101
${ONOS_REST_PORT}    8181

# Scale pipeline values
${olt}  1
${pon}  1
${onu}  1

${enableFlowProvisioning}   true
${enableSubscriberProvisioning}     true

${workflow}     att
${withEapol}    false
${withDhcp}    false
${withIgmp}    false
# as of now the LLDP flow is always installed
${withLLDP}   true

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***

Create and Enable devices
    [Documentation]  Create and enable the OLTs in VOLTHA
    [Tags]      non-critical    setup
    ${olt_device_ids}=      Create List
    FOR    ${INDEX}    IN RANGE    0    ${olt}
        ${olt_device_id}=    Create Device  bbsim${INDEX}     50060     openolt
        Enable Device    ${olt_device_id}
        Append To List  ${olt_device_ids}    ${olt_device_id}
    END

    Set Suite Variable    ${olt_device_ids}

Onu Activation in VOLTHA
    [Documentation]    Check that all ONUs reach the ACTIVE/ENABLED state in VOLTHA
    [Tags]      non-critical    activation    plot-voltha-onus
    Wait For ONUs In VOLTHA     ${total_onus}

Port Discovery in ONOS
    [Documentation]    Check that all the UNI ports show up in ONOS
    [Tags]      non-critical    activation    plot-onos-ports
    Wait for Ports in ONOS      ${onos_ssh_connection}  ${total_onus}   BBSM

Flows validation in VOLTHA before subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]      non-critical    flow-before   plot-voltha-flows-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for Logical Devices flows   ${workflow}    ${total_onus}    ${olt}    false
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in VOLTHA Adapters before subscriber provisioning
    [Documentation]  Check that all flows has been store in devices of type openolt
    [Tags]      non-critical    flow-before   plot-voltha-openolt-flows-before  only-me
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for OpenOLT Devices flows   ${workflow}    ${total_onus}    ${olt}    false
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in ONOS before subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]      non-critical    flow-before   plot-onos-flows-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for all flows to in ADDED state    ${onos_ssh_connection}
    ...     ${workflow}    ${total_onus}    ${olt}    false     ${withEapol}    ${withDhcp}
    ...     ${withIgmp}   ${withLLDP}

Wait for subscribers to be Authenticated
    [Documentation]    Check that all subscribers have successfully authenticated
    [Tags]      non-critical    authentication    plot-onos-auth
    Wait for AAA Authentication     ${onos_ssh_connection}  ${total_onus}

Provision subscribers
    [Documentation]    Provision data plane flows for all the subscribers
    [Tags]      non-critical    provision
    Should Be Equal   ${enableSubscriberProvisioning}     true
    ${olts}=    List OLTs   ${onos_ssh_connection}
    FOR     ${olt}  IN  @{olts}
        Provision all subscribers on device  ${onos_ssh_connection}     ${ONOS_SSH_IP}     ${ONOS_REST_PORT}  ${olt}
    END

Flows validation in VOLTHA after subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]      non-critical    flow-after    plot-voltha-flows-after
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for Logical Devices flows   ${workflow}    ${total_onus}    ${olt}    true
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in VOLTHA Adapters after subscriber provisioning
    [Documentation]  Check that all flows has been store in devices of type openolt
    [Tags]      non-critical    flow-after   plot-voltha-openolt-flows-after    only-me
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for OpenOLT Devices flows   ${workflow}    ${total_onus}    ${olt}    true
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in ONOS after subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]      non-critical    flow-after    plot-onos-flows-after
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for all flows to in ADDED state    ${onos_ssh_connection}
    ...     ${workflow}    ${total_onus}    ${olt}    true      ${withEapol}    ${withDhcp}
    ...     ${withIgmp}   ${withLLDP}

Wait for subscribers to have an IP
    [Documentation]    Check that all subscribers have received a DHCP_ACK
    [Tags]      non-critical    dhcp  plot-onos-dhcp
    Wait for DHCP Ack     ${onos_ssh_connection}  ${total_onus}

Disable and Delete devices
    [Documentation]  Disable and delete the OLTs in VOLTHA
    [Tags]      non-critical    teardown
    FOR    ${olt_device_id}    IN  @{olt_device_ids}
        Disable Device  ${olt_device_id}
        Delete Device  ${olt_device_id}
    END

    Set Suite Variable    ${olt_device_ids}

*** Keywords ***
Setup Suite
    [Documentation]    Setup test global variables, open an SSH connection to ONOS and starts a timer
    Set Suite Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Suite Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}

    ${total_onus}=   Evaluate    ${olt} * ${pon} * ${onu}
    Set Suite Variable  ${total_onus}

    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable  ${onos_ssh_connection}

Teardown Suite
   [Documentation]    Close the SSH connection to ONOS
    Close ONOS SSH Connection   ${onos_ssh_connection}