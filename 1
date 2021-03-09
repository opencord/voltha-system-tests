# Copyright 2021 - present Open Networking Foundation
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
Documentation     Test Voltha Components Software Upgrade
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
#${KUBERNETES_CONFIGS_DIR}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${NAMESPACE}      voltha
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

${suppressaddsubscriber}    True

# Voltha Components to Test for Software Upgrade need to be passed in the following variable in format:
# <comp-label>,<comp-container>,<comp-image>*<comp-label>,<comp-container>,<comp-image>*
# Example: adapter-open-olt,adapter-open-olt,voltha/voltha-openolt-adapter:3.1.3*
${voltha_comps_under_test}    ${EMPTY}

*** Test Cases ***
Test Voltha Components Minor Version Upgrade
    [Documentation]    Validates the Voltha Components Minor Version Upgrade doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Requirement: Components to test needs to be passed in robot command variable 'voltha_comps_under_test' in the format:
    ...    <comp-label>,<comp-container>,<comp-image>*<comp-label>,<comp-container>,<comp-image>*
    ...    Check [VOL-3843] for more details
    [Tags]    functional   VolthaCompMinorVerUpgrade
    [Setup]    Start Logging    VolthaCompMinorVerUpgrade
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    VolthaCompMinorVerUpgrade
    ...           AND             Delete All Devices and Verify
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBeforeUpgrade}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${num_comps_under_test}=    Get Length    ${list_voltha_comps_under_test}
    FOR    ${I}    IN RANGE    0    ${num_comps_under_test}
        ${label}=    Set Variable    ${list_voltha_comps_under_test}[${I}][label]
        ${container}=    Set Variable    ${list_voltha_comps_under_test}[${I}][container]
        ${image}=    Set Variable    ${list_voltha_comps_under_test}[${I}][image]
        ${pod_image}    ${app_ver}    ${helm_chart}    Get Pod Image And App Version And Helm Chart By Label
        ...    ${NAMESPACE}    app    ${label}
        Log    ${label}: image, app ver & helm chart before upgrade: ${pod_image}, ${app_ver} & ${helm_chart}
        ${deployment}=    Wait Until Keyword Succeeds    ${timeout}    15s
        ...    Get K8s Deployment by Pod Label    ${NAMESPACE}    app    ${label}
        Wait Until Keyword Succeeds    ${timeout}    15s    Deploy Pod New Image    ${NAMESPACE}    ${deployment}
        ...    ${container}    ${image}
        Wait Until Keyword Succeeds    ${timeout}    3s    Validate Pods Status By Label    ${NAMESPACE}
        ...    app    ${label}    Running
        Wait Until Keyword Succeeds    ${timeout}    3s    Pods Are Ready By Label    ${NAMESPACE}    app    ${label}
        Wait Until Keyword Succeeds    ${timeout}    3s    Verify Pod Image    ${NAMESPACE}    app    ${label}    ${image}
        ${pod_image_1}    ${app_ver_1}    ${helm_chart_1}    Get Pod Image And App Version And Helm Chart By Label
        ...    ${NAMESPACE}    app    ${label}
        Log    ${label}: image, app ver & helm chart after upgrade: ${pod_image_1}, ${app_ver_1} & ${helm_chart_1}
        Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test     ${suppressaddsubscriber}
    END
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterUpgrade}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterUpgrade}    ${countBeforeUpgrade}
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    Create Voltha Comp Under Test List

Teardown Suite
    [Documentation]    Tear down steps for the suite
    Run Keyword If    ${has_dataplane}    Clean Up Linux

Create Voltha Comp Under Test List
    [Documentation]    Creates a list of Voltha Components to Test from the input variable string
    ...    The input string is expected to be in format:
    ...    <comp-label>,<comp-container>,<comp-image>*<comp-label>,<comp-container>,<comp-image>*
    ${list_voltha_comps_under_test}    Create List
    @{comps_under_test_arr}=    Split String    ${voltha_comps_under_test}    *
    ${num_comps_under_test}=    Get Length    ${comps_under_test_arr}
    FOR    ${I}    IN RANGE    0    ${num_comps_under_test}-1
        @{comp_under_test_arr}=    Split String    ${comps_under_test_arr[${I}]}    ,
        ${label}=    Set Variable    ${comp_under_test_arr[0]}
        ${container}=    Set Variable    ${comp_under_test_arr[1]}
        ${image}=    Set Variable    ${comp_under_test_arr[2]}
        ${comp_under_test}    Create Dictionary    label    ${label}    container    ${container}    image    ${image}
        Append To List    ${list_voltha_comps_under_test}    ${comp_under_test}
    END
    Log    ${list_voltha_comps_under_test}
    Set Suite Variable    ${list_voltha_comps_under_test}
