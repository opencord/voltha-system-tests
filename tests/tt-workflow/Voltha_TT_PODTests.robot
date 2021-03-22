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
Documentation     Test various functional end-to-end scenarios for TT workflow
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
${teardown_device}    True
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Reboot TT ONUs Physically - Clean Up
    [Documentation]   This test reboots ONUs physically before execution all the tests
    ...    Test case runs only on the PODs that are configured with PowerSwitch that
    ...    controls the power off/on ONUs/OLT remotely (simulating a physical reboot)
    [Tags]    functional   PowerSwitch    RebootAllTTONUs
    [Setup]    Start Logging    RebootAllTTONUs
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RebootAllTTONUs
    Power Switch Connection Suite    ${web_power_switch.ip}    ${web_power_switch.user}    ${web_power_switch.password}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Disable Switch Outlet    ${src['power_switch_port']}
        Sleep    10s
        Enable Switch Outlet    ${src['power_switch_port']}
    END

Sanity E2E Test for TT (HSIA, VoD, VoIP)
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful DHCP/E2E ping (no EAPOL and DHCP flows) for the tech profile that is used
    ...    Traffic sent with same vlan from different RGs,
    ...    should reach the NNI port on the OLT with the expected double tagged vlan ids
    ...    Inner vlans from the RG should not change
    [Tags]    sanityTT
    [Setup]    Run Keywords    Start Logging    SanityTestTT
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTestTT
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test TT
    #Run Keyword If    ${has_dataplane}    Clean Up Linux

Sanity E2E Test for TT (MCAST)
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful DHCP/E2E ping (no EAPOL and DHCP flows) for the tech profile that is used
    ...    Traffic sent with same vlan from different RGs,
    ...    should reach the NNI port on the OLT with the expected double tagged vlan ids
    ...    Inner vlans from the RG should not change
    [Tags]    sanityTT-MCAST
    [Setup]    Run Keyword    Start Logging    SanityTestTT-MCAST
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTestTT-MCAST
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test TT MCAST

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}


Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup


Teardown Suite
    [Documentation]    Tear down steps for the suite
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${teardown_device}    Delete All Devices And Verify
