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
# FIXME Can we use the same test against BBSim and Hardware?

*** Settings ***
Documentation     ONOS high avaliablity tests
Suite Setup       Setup Suite
Test Setup        Setup
Test Teardown     Teardown
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
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot
Resource          ../../libraries/power_switch.robot

*** Variables ***
${POD_NAME}       flex-ocp-cord
${KUBERNETES_CONF}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}    ~/pod-configs/kubernetes-configs
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${NAMESPACE}      default
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    True
${scripts}        ../../scripts
${workflow}    ATT

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Verify restart ONOS instace master of device after subscriber is provisioned
    [Documentation]    Restat ONOS instance master of a given device and check that during restart and after the
    ...    subscriuber still has dataplane traffic.
    ...    Prerequisite : ONUs are authenticated and pingable, thus setup and sanity is performed.
    [Tags]    onosHa   VOL-3436   onosMasterRestart
    [Setup]    Run Keyword    Start Logging    onosMasterRestart
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    onosMasterRestart
    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If   '${workflow}' == 'ATT'    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Run Keyword If   '${workflow}' == 'DT'    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    ${node_id}=    Wait Until Keyword Succeeds    20s    5s    Get Master Instace in ONOS    ${of_id}
    ${podName}    Set Variable     ${node_id}
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Name    ${NAMESPACE}    ${podName}
    Sleep    60s
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Name    ${NAMESPACE}
    ...    ${podName}    Running
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If   '${workflow}' == 'ATT'    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Run Keyword If   '${workflow}' == 'DT'    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    Log to console    Pod ${podName} deleted and sanity checks passed successfully

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
