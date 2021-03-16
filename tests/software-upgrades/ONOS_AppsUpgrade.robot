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

*** Settings ***
Documentation     Test ONOS Apps Software Upgrade
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
${uprate}         0
${dnrate}         0
${has_dataplane}    True
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# ONOS Apps to Test for Software Upgrade need to be passed in the following variable in format:
# <app-name>,<version>,<oar-url>*<app-name>,<version>,<oar-url>*
# Example: org.opencord.aaa,2.3.0.SNAPSHOT,
# https://oss.sonatype.org/content/groups/public/org/opencord/aaa-app/2.3.0-SNAPSHOT/aaa-app-2.3.0-20201210.223737-1.oar*
${onos_apps_under_test}    ${EMPTY}

*** Test Cases ***
Test ONOS App Minor Version Upgrade
    [Documentation]    Validates the ONOS App Minor Version Upgrade doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Requirement: Apps to test needs to be passed in robot command variable 'onos_apps_under_test' in the format:
    ...    <app-name>,<version>,<oar-url>*<app-name>,<version>,<oar-url>*
    ...    Check [VOL-3844] for more details
    [Tags]    functional    ONOSAppMinorVerUpgrade
    [Setup]    Run Keywords    Start Logging    ONOSAppMinorVerUpgrade
    ...        AND    Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ONOSAppMinorVerUpgrade
    ...           AND             Delete All Devices and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    ${onos_url}=    Set Variable    http://karaf:karaf@${ONOS_REST_IP}:${ONOS_REST_PORT}
    ${num_apps_under_test}=    Get Length    ${list_onos_apps_under_test}
    # Set log level to DEBUG for all apps under test
    FOR    ${J}    IN RANGE    0    ${num_apps_under_test}
        ${app_ut}=    Set Variable    ${list_onos_apps_under_test}[${J}][app]
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command on open connection    ${onos_ssh_connection}
        ...    log:set ${app_ut} DEBUG
    END
    FOR    ${I}    IN RANGE    0    ${num_apps_under_test}
        ${app}=    Set Variable    ${list_onos_apps_under_test}[${I}][app]
        ${version}=    Set Variable    ${list_onos_apps_under_test}[${I}][version]
        ${url}=    Set Variable    ${list_onos_apps_under_test}[${I}][url]
        ${oar_file}=    Set Variable    ${CURDIR}/../../tests/data/onos-files/${app}-${version}.oar
        Download App OAR File    ${url}    ${oar_file}
        ${app_details}    Get ONOS App Details    ${onos_url}    ${app}
        Log    ${app}: before upgrade: ${app_details}
        Delete ONOS App    ${onos_url}    ${app}
        Verify ONOS Apps Active Except App Under Test    ${onos_url}    ${app}
        Install And Activate ONOS App    ${onos_url}    ${oar_file}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify ONOS App Active    ${onos_url}    ${app}    ${version}
        ${app_details_1}    Get ONOS App Details    ${onos_url}    ${app}
        Log    ${app}: after upgrade: ${app_details_1}
        Verify ONOS Pod Restart    False
        Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test    True
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    Create ONOS Apps Under Test List
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable    ${onos_ssh_connection}

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    Close All ONOS SSH Connections

Verify ONOS Apps Active Except App Under Test
    [Documentation]    Verifies all the apps defined in input yaml are active except for the app under test
    [Arguments]    ${onos_url}    ${app_under_test}
    ${num_onos_apps}=    Get Length    ${onos_apps}
    FOR    ${I}    IN RANGE    0    ${num_onos_apps}
        Continue For Loop If    '${app_under_test}'=='${onos_apps}[${I}]'
        Verify ONOS App Active    ${onos_url}    ${onos_apps}[${I}]
    END

Download App OAR File
    [Documentation]    This keyword downloads the app oar file from the given url to the specified location
    [Arguments]    ${oar_url}    ${oar_file}
    ${rc}    Run And Return Rc    curl -L ${oar_url} > ${oar_file}
    Should Be Equal As Integers    ${rc}    0

Create ONOS Apps Under Test List
    [Documentation]    Creates a list of ONOS Apps to Test from the input variable string
    ...    The input string is expected to be in format:
    ...    <app-name>,<version>,<oar-url>*<app-name>,<version>,<oar-url>*
    ${list_onos_apps_under_test}    Create List
    @{apps_under_test_arr}=    Split String    ${onos_apps_under_test}    *
    ${num_apps_under_test}=    Get Length    ${apps_under_test_arr}
    FOR    ${I}    IN RANGE    0    ${num_apps_under_test}-1
        @{app_under_test_arr}=    Split String    ${apps_under_test_arr[${I}]}    ,
        ${app}=    Set Variable    ${app_under_test_arr[0]}
        ${version}=    Set Variable    ${app_under_test_arr[1]}
        ${url}=    Set Variable    ${app_under_test_arr[2]}
        ${app_under_test}    Create Dictionary    app    ${app}    version    ${version}    url    ${url}
        Append To List    ${list_onos_apps_under_test}    ${app_under_test}
    END
    Log    ${list_onos_apps_under_test}
    Set Suite Variable    ${list_onos_apps_under_test}
