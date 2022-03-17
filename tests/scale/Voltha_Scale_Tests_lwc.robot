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
#   helm upgrade --install -n voltha1 bbsim0 onf/bbsim --set ol6t_id=16 -f examples/dt-values.yaml --set pon=16,onu=16 --version 4.6.0 --set oltRebootDelay=5
#   robot -v pon:16 -v onu:16 tests/scale/Voltha_Scale_Tests_lwc.robot



*** Settings ***
Documentation     Collect measurements on VOLTHA performances
Suite Setup       Setup Suite
#Test Setup        Setup
#Test Teardown     Teardown
Suite Teardown    Teardown Suite
Library           BuiltIn
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
Resource          ../../libraries/utils.robot
Resource          ../../libraries/bbsim.robot
Resource          ../../libraries/lwc.robot
Resource          ../../variables/variables.robot

*** Variables ***

${LWC_REST_IP}    127.0.0.1
${LWC_REST_PORT}    8182

${BBSIM_REST_IP}    127.0.0.1
${BBSIM_REST_PORT}    50071

${NAMESPACE}      default

# Scale pipeline values
${stackId}  1
${olt}  1
${pon}  1
${onu}  1

${enableFlowProvisioning}   true
${enableSubscriberProvisioning}     true

${workflow}     dt
${withEapol}    false
${withDhcp}    false
${withIgmp}    false
# as of now the LLDP flow is always installed
${withLLDP}   false

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

${timeout}    10m

*** Test Cases ***

Create and Enable devices
    [Documentation]  Create and enable the OLTs in VOLTHA
    [Tags]      setup
    ${olt_device_ids}=      Create List
    FOR    ${INDEX}    IN RANGE    0    ${olt}
        ${olt_device_id}=    Create Device  bbsim${INDEX}     50060     openolt
        Enable Device    ${olt_device_id}
        Append To List  ${olt_device_ids}    ${olt_device_id}
    END

    Set Suite Variable    ${olt_device_ids}

OLTs in LWC
    [Documentation]  Check that LWC recognize the correct number of OLTs
    [Tags]  activation  plot-lwc-olts
    Wait for Olts in LWC    ${olt}

Onu Activation in VOLTHA
    [Documentation]    Check that all ONUs reach the ACTIVE/ENABLED state in VOLTHA
    [Tags]      activation    plot-voltha-onus
    Wait For ONUs In VOLTHA     ${total_onus}    ${timeout}

Port Discovery in LWC
    [Documentation]    Check that all the UNI ports show up in LWC
    [Tags]      activation    plot-lwc-ports
    Wait for Ports in LWC      ${total_onus}

Flows validation in VOLTHA before subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]      flow-before   plot-voltha-flows-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for Logical Devices flows   ${workflow}    ${total_onus}    ${olt}    false
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}    ${timeout}

Flows validation in VOLTHA Adapters before subscriber provisioning
    [Documentation]  Check that all flows has been store in devices of type openolt
    [Tags]      flow-before   plot-voltha-openolt-flows-before  only-me
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for OpenOLT Devices flows   ${workflow}    ${total_onus}    ${olt}    false
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in LWC before subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]      flow-before   plot-onos-flows-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true

    Wait for flows in LWC    ${workflow}    ${total_onus_per_olt}    ${olt}    false
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}   ${withLLDP}

#Wait for subscribers to be Authenticated
#    [Documentation]    Check that all subscribers have successfully authenticated
#    [Tags]      authentication    plot-onos-auth
#
#    ${onos_devices}=    Compute Device IDs
#    FOR     ${deviceId}     IN  @{onos_devices}
#        Wait for AAA Authentication     ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus_per_olt}   ${deviceId}
#    END
#
Provision subscribers
    [Documentation]    Provision data plane flows for all the subscribers
    [Tags]      provision   teo
    Should Be Equal   ${enableSubscriberProvisioning}     true
    ${url}=     Catenate    SEPARATOR=:     ${LWC_REST_IP}  ${LWC_REST_PORT}
    Provision all subscribers on LWC    ${url}

Flows validation in VOLTHA after subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]      flow-after    plot-voltha-flows-after
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true

    Wait for Logical Devices flows   ${workflow}    ${total_onus}    ${olt}    true
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}    ${timeout}

Flows validation in VOLTHA Adapters after subscriber provisioning
    [Documentation]  Check that all flows has been store in devices of type openolt
    [Tags]      flow-after   plot-voltha-openolt-flows-after    only-me
    Should Be Equal   ${enableFlowProvisioning}     true
    Wait for OpenOLT Devices flows   ${workflow}    ${total_onus}    ${olt}    true
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in LWC after subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]      flow-before   plot-onos-flows-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true

    Wait for flows in LWC    ${workflow}    ${total_onus_per_olt}    ${olt}    true
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}   ${withLLDP}

#Wait for subscribers to have an IP
#    [Documentation]    Check that all subscribers have received a DHCP_ACK
#    [Tags]      dhcp  plot-onos-dhcp
#    ${onos_devices}=    Compute Device IDs
#    FOR     ${deviceId}     IN  @{onos_devices}
#        Wait for DHCP Ack     ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus_per_olt}     ${workflow}     ${deviceId}
#    END
#
Disable and Delete devices
    [Documentation]  Disable and delete the OLTs in VOLTHA
    [Tags]      non-critical    teardown

    ${rc}    ${output}=     Run And Return Rc And Output    voltctl -c ${VOLTCTL_CONFIG} device list -m 32MB -f Type=openolt -q
    Should Be Equal As Integers    ${rc}    0   Failed to get device list from voltctl: ${output}
    Log     ${output}
    ${devices}=     Split To Lines  ${output}
    Log     ${devices}

    FOR     ${id}   IN  @{devices}
        Disable Device  ${id}
        Delete Device  ${id}
    END

*** Keywords ***
Setup Suite
    [Documentation]    Setup test global variables, open an SSH connection to ONOS and starts a timer
    Set Suite Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Suite Variable    ${VOLTCTL_CONFIG}    %{VOLTCONFIG}

    Should Be Equal As Integers    ${olt}    1  msg="LWC allows a single OLT for now"

    ${total_onus}=   Evaluate    ${olt} * ${pon} * ${onu}
    Log To Console  Testing for topology: ${olt} OLT * ${pon} PON * ${onu} ONU
    Log To Console  Total ONUs: ${total_onus}
    Set Suite Variable  ${total_onus}

    ${total_onus_per_olt}=   Evaluate    ${pon} * ${onu}
    Set Suite Variable  ${total_onus_per_olt}

    Create Session    LWC    http://${LWC_REST_IP}:${LWC_REST_PORT}

Teardown Suite
   [Documentation]    Close the SSH connection to ONOS
    Close All ONOS SSH Connections