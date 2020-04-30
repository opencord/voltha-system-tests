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
# FIXME Can we use the same test against BBSim and Hardware?

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
${NAMESPACE}      default
${KIND_VOLTHA}    ~/kind-voltha
${ONOS_SSH_IP}  127.0.0.1
${ONOS_SSH_PORT}    8101

# target values in the test
${olt}  1
${pon}  1
${onu}  1

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

*** Keywords ***
Setup Suite
    [Documentation]    Deploy VOLTHA
    Set Suite Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Suite Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}

    ${total_onus}=   Evaluate    ${olt} * ${pon} * ${onu}
    Set Suite Variable  ${total_onus}

    Log     Implement me!!
    # NOTE we may need to deploy VOLTHA within the tests as
    # we need to know the settings we used to deploy (how many OLTs, the service names, ...)
#    Set Environment Variable    DEPLOY_K8S  no
#    Set Environment Variable    INFRA_NS    default
#    Set Environment Variable    BBSIM_NS    default
#    Set Environment Variable    ADAPTER_NS  default
#    Set Environment Variable    VOLTHA_NS   default
#    Set Environment Variable    INSTALL_KUBECTL     no
#    Set Environment Variable    INSTALL_HELM        no
#    Set Environment Variable    NUM_OF_BBSIM        no
#    Set Environment Variable    NUM_OF_OPENONU      no
#    # TODO add support for custom charts
#    ${voltha_up}=   Run
#    ...     ${KIND_VOLTHA}/voltha up
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



