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

*** Settings ***
Documentation     Test various failure scenarios
Suite Setup       Setup Suite
Test Setup        Setup
Test Teardown     Teardown
#Suite Teardown    Teardown Suite
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
${DEFAULTSPACE}      default
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

*** Test Cases ***
Verify OLT Soft Reboot
    [Documentation]    Test soft reboot of the OLT using voltctl command
    [Tags]    VOL-2745   OLTSoftReboot    notready
    [Setup]    Start Logging    OLTSoftReboot
    #...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    OLTSoftReboot
    #...           AND             Delete Device and Verify
    ## Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    #Run Keyword If    ${has_dataplane}    Clean Up Linux
    #Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    Run Keyword And Ignore Error    Collect Logs
    #Verify that ping fails
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Wait for the OLT to come back up
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s
    ...    Check Remote System Reachability    True    ${olt_ssh_ip}
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    # Check OLT states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    Run Keyword And Ignore Error    Collect Logs
    #Check after reboot that ONUs are active, authenticated/DHCP/pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
