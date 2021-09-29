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
${NAMESPACE}      voltha
${INFRA_NAMESPACE}      default
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    True
${numOfOnos}    1
${scripts}        ../../scripts
${workflow}    ATT

${suppressaddsubscriber}    True

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

*** Test Cases ***
Verify restart ONOS instace master of device after subscriber is provisioned
    [Documentation]    Restat ONOS instance master of a given device and check that during restart and after the
    ...    subscriuber still has dataplane traffic.
    ...    Prerequisite : ONUs are authenticated and pingable, thus setup and sanity is performed.
    [Tags]    onosHa   VOL-3436   onosMasterRestart
    [Setup]    Start Logging     onosMasterRestart
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    onosMasterRestart
    ${numOfOnos}=    Wait Until Keyword Succeeds    20s    5s    Get Number of Running Pods Number By Label    ${INFRA_NAMESPACE}
    ...    app    onos-classic
    Should Not Be Equal As Integers    ${numOfOnos}    0    Error fetching number of ONOS instances
    Pass Execution If    ${numOfOnos} == 1    Skipping test: just one instance of ONOS
    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If   '${workflow}' == 'ATT'    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Run Keyword If   '${workflow}' == 'DT'    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    360s    15s    Validate OLT Device in ONOS    ${olt_serial_number}
        ${node_id}=    Wait Until Keyword Succeeds    20s    5s    Get Master Instace in ONOS    ${of_id}
        @{onos_id}=    Split String    ${node_id}    -
        ${podName}=    Catenate    SEPARATOR=-    voltha-infra-onos-classic    ${onos_id[1]}
        Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Name    ${INFRA_NAMESPACE}    ${podName}
        Sleep    60s
        Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Name    ${INFRA_NAMESPACE}
        ...    ${podName}    Running
        # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
        Run Keyword If    ${has_dataplane}    Clean Up Linux
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get NNI Port in ONOS    ${of_id}
        Set Global Variable    ${nni_port}
        ${num_onus}=    Set Variable    ${list_olts}[${I}][onucount]
        Run Keyword If   '${workflow}' == 'ATT'    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Perform Sanity Test Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}    ${num_onus}
        ...    ${suppressaddsubscriber}
        Run Keyword If   '${workflow}' == 'DT'    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Perform Sanity Test DT Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}    ${num_onus}
    END
    Log to console    Pod ${podName} deleted and sanity checks passed successfully

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
