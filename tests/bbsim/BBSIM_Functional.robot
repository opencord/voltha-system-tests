# Copyright 2020 - present Open Networking Foundation
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

# These test make sure the basic BBSim functionalitites are working

*** Settings ***
Documentation     Validates BBSim functionalities
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite
Library           Collections
Library           String
Library           OperatingSystem
Library           XML
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/k8s.robot
Resource          ../../libraries/bbsim.robot

*** Variables ***
${ONOS_SSH_IP}  127.0.0.1
${ONOS_SSH_PORT}    8101
${ONOS_REST_PORT}    8181

${workflow}     att
${total_onus}   1
${bbsim_namespace}  voltha
${olt_device_id}

*** Test Cases ***

Enable OLT
    [Documentation]  Enable the OLT and check the ONUs
    ${olt_device_id}=    Create Device  bbsim0     50060     openolt
    Enable Device    ${olt_device_id}

    Set Suite Variable    ${olt_device_id}

    Wait for Ports in ONOS      ${onos_ssh_connection}  ${total_onus}   BBSM

Restart Auth
    [Documentation]  Waits for subscribers to be authenitcated and the issue a new requests
    [Timeout]   60

    # TODO this is needed for ATT only
    Wait for AAA Authentication     ${onos_ssh_connection}  ${total_onus}

    ${bbsim_pod}=    Get Pod Name By Label   ${bbsim_namespace}  app     bbsim
    List ONUs   ${bbsim_namespace}  ${bbsim_pod}
    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    aaa-reset-all-devices
    Restart Auth    ${bbsim_namespace}  ${bbsim_pod}    BBSM00000001

    Wait for AAA Authentication     ${onos_ssh_connection}  ${total_onus}

Enable Subscriber
    [Documentation]  does something
    ${bbsim_pod}=    Get Pod Name By Label   ${bbsim_namespace}  app     bbsim
    List ONUs   ${bbsim_namespace}  ${bbsim_pod}
    # TODO parametrize
    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    volt-add-subscriber-access of:00000a0a0a0a0a00 16


Restart DHCP
    [Documentation]  Waits for subscribers to have an IP and the issue a new DHCP requests
    [Timeout]   60

    Wait for DHCP Ack     ${onos_ssh_connection}  ${total_onus}     ${workflow}

    ${bbsim_pod}=    Get Pod Name By Label   ${bbsim_namespace}  app     bbsim
    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    dhcpl2relay-clear-allocations
    Restart DHCP    ${bbsim_namespace}  ${bbsim_pod}    BBSM00000001
    Wait for DHCP Ack     ${onos_ssh_connection}  ${total_onus}     ${workflow}

*** Keywords ***
Setup Suite
    [Documentation]    Setup test global variables, open an SSH connection to ONOS and enables the OLT
    Set Suite Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Suite Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}

    # establish a connection to ONOS
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable  ${onos_ssh_connection}

Teardown Suite
    [Documentation]    Close the SSH connection to ONOS and removes the OLT
    Close ONOS SSH Connection   ${onos_ssh_connection}

    Disable Device  ${olt_device_id}
    Delete Device  ${olt_device_id}