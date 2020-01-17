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
Documentation     Test various end-to-end scenarios
Suite Setup       Common Test Suite Setup
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
${has_dataplane}    False
${external_libs}    True
${teardown_device}    False
${scripts}        ../../scripts

*** Test Cases ***
Delete OLT, ReAdd OLT and Perform Sanity Test
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Disable and Delete the OLT
    ...    Create/Enable the same OLT again
    ...    Validate authentication/DHCP/E2E pings succeed for all the ONUs connected to the OLT
    [Tags]    functional    DeleteOL   sanity
    #[Setup]    None
    [Teardown]    NONE
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${has_dataplane}    Delete Device and Verify
    Run Keyword and Ignore Error    Collect Logs
    # Recreate the OLT
    Run Keyword If    ${has_dataplane}    Setup
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test
    Run Keyword and Ignore Error    Collect Logs

*** Keywords ***
Setup
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ip}    ${olt_user}    ${olt_pass}
    Sleep    60s
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${EMPTY}    ${olt_device_id}
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}

Teardown
    [Documentation]    kills processes and cleans up interfaces on src+dst servers
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${external_libs}        Run Keyword and Ignore Error
    ...    Log Kubernetes Containers Logs Since Time
    ...    ${datetime}    ${container_list}

Teardown Suite
    [Documentation]    Clean up device if desired
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify

Delete All Devices and Verify
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Clear devices from VOLTHA
    Disable Devices In Voltha    Root=true
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Devices Disabled In Voltha    Root=true
    Delete Devices In Voltha    Root=true
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Empty Device List
    # Clear devices from ONOS
    Remove All Devices From ONOS
    ...    http://karaf:karaf@${k8s_node_ip}:${ONOS_REST_PORT}
