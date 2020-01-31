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
${timeout}        90s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    False
${scripts}        ../../scripts
${container_log_path}    /tmp

*** Test Cases ***
Adding the same OLT before and after enabling the device
    [Documentation]    Create OLT, Create the same OLT again and Check for the Error message
    [Tags]    VOL-2405   VOL-2406   AddSameOLT   functional
    [Setup]    None
    [Teardown]   End Log Capture
    Start Log Capture    AddSameOLT
    Run Keyword If    ${has_dataplane}    Delete Device and Verify
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    ...    ${EMPTY}    ${olt_device_id}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${olt_ip}:${OLT_PORT}
    Should Not Be Equal As Integers    ${rc}    0
    Should Contain     ${output}     Device is already pre-provisioned
    #Enable the created OLT device
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${olt_ip}:${OLT_PORT}
    Should Not Be Equal As Integers    ${rc}    0
    Log    ${output}
    Should Contain     ${output}    Device is already pre-provisioned
    Log    "This OLT is added already and enabled"

Test Disable different device id which is not in the device list
    [Documentation]    Disable a device id which is not listed in the voltctl device list
    ...    command and ensure that error message is shown.
    [Tags]    functional    DisableInvalidDevice    VOL-2412
    [Setup]    None
    [Teardown]    End Log Capture
    Start Log Capture    DisableInvalidDevice
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    @{ids}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${device_id}=    Get From Dictionary    ${value}    id
        Append To List    ${ids}    ${device_id}
    END
    #Create a new fake device id
    ${fakeDeviceId}    Replace String Using Regexp          ${device_id}    \\d\\d     xx    count=1
    Log     ${fakeDeviceId}
    #Ensure that the new id created is not in the device id list
    List Should Not Contain Value    ${ids}    ${fakeDeviceId}
    #Disable fake device id
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${fakeDeviceId}
    Should Contain    ${output}     Error while disabling '${fakeDeviceId}': rpc error: code = NotFound desc
