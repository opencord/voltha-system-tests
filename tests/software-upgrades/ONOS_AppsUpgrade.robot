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
Documentation     Test various end-to-end scenarios
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

*** Test Cases ***
Test ONOS App Minor Version Upgrade
    [Documentation]    Validates the ONOS App Minor Version Upgrade doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Requirement: App to test needs to be mentioned in `tests/data/onos-app-upgrade.yaml` file
    ...    Requirement: App OAR file needs to be present in `tests/data/onos-files` folder
    ...    Requirement: App name & OAR file name needs to be similar (e.g.: org.opencord.aaa & org.opencord.aaa.oar)
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
    ${num_apps_under_test}=    Get Length    ${onos_apps_under_test}
    FOR    ${I}    IN RANGE    0    ${num_apps_under_test}
        Delete ONOS App    ${onos_url}    ${onos_apps_under_test}[${I}]
        Verify ONOS Apps Active Except App Under Test    ${onos_url}    ${onos_apps_under_test}[${I}]
        Install And Activate ONOS App    ${onos_url}
        ...    ${CURDIR}/../../tests/data/onos-files/${onos_apps_under_test}[${I}].oar
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify ONOS App Active    ${onos_url}    ${onos_apps_under_test}[${I}]
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

Verify ONOS Apps Active Except App Under Test
    [Documentation]    Verifies all the apps defined in input yaml are active except for the app under test
    [Arguments]    ${onos_url}    ${app_under_test}
    ${num_onos_apps}=    Get Length    ${onos_apps}
    FOR    ${I}    IN RANGE    0    ${num_onos_apps}
        Continue For Loop If    '${app_under_test}'=='${onos_apps}[${I}]'
        Verify ONOS App Active    ${onos_url}    ${onos_apps}[${I}]
    END
