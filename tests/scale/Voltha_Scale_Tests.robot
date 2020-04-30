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
Library           Timer
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/voltha.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot

*** Variables ***
${ONOS_SSH_IP}  127.0.0.1
${ONOS_SSH_PORT}    8101

# Scale pipeline values
${olt}  1
${pon}  1
${onu}  1

${enableLLDP}   false
${enableFlowProvisioning}   true
${enableSubscriberProvisioning}     true

${flowsBeforeProvisioning}  1
${flowsAfterProvisioning}  1

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Onu Activation in VOLTHA
    [Documentation]    Check that all ONUs reach the ACTIVE/ENABLED state in VOLTHA
    [Tags]    activation
    ${total_onus}=   Evaluate    ${olt} * ${pon} * ${onu}
    Wait For ONUs In VOLTHA     ${total_onus}

Port Discovery in ONOS
    [Documentation]    Check that all the UNI ports show up in ONOS
    [Tags]    activation
    Wait for Ports in ONOS      ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus}   BBSM

Flows validation in VOLTHA before subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]    flow-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Log     TODO

Flows validation in ONOS before subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]    flow-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Log     TODO

Wait for subscribers to be Authenticated
    [Documentation]    Check that all subscribers have successfully authenticated
    [Tags]    authentication
    Wait for AAA Authentication     ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus}

Provision subscribers
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]    provision
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableSubscriberProvisioning} == false
    Log     TODO

Flows validation in VOLTHA after subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]    flow-after
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Log     TODO

Flows validation in ONOS after subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]    flow-after
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Log     TODO

Wait for subscribers to have an IP
    [Documentation]    Check that all subscribers have received a DHCP_ACK
    [Tags]    dhcp
    Wait for DHCP Ack     ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus}

*** Keywords ***
Setup Suite
    [Documentation]    Deploy VOLTHA
    Set Suite Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Suite Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}

    ${total_onus}=   Evaluate    ${olt} * ${pon} * ${onu}
    Set Suite Variable  ${total_onus}

    # TODO support multiple OLTs
    ${olt_device_id}=    Create Device  bbsim     50060
    Set Suite Variable    ${olt_device_id}
    Enable Device    ${olt_device_id}

    Configure Timer     10 minutes  0 seconds   SuiteTimer
    Start Timer     SuiteTimer

Teardown Suite
    Stop Timer     SuiteTimer
    Verify Single Timer    10 minutes   0 seconds   SuiteTimer
    Disable Device  ${olt_device_id}
    Delete Device  ${olt_device_id}



