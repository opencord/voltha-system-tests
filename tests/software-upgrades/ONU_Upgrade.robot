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
Documentation     Tests ONU Software Upgrade
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
Resource          ../../libraries/bbsim.robot
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
${has_dataplane}    True
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

${suppressaddsubscriber}    True

# ONU Image to test for Upgrade needs to be passed in the following format:
${image_version}    ${EMPTY}
# Example value: BBSM_IMG_00002
${image_url}    ${EMPTY}
# Example value: http://bbsim0:50074/images/software-image.img
${image_vendor}    ${EMPTY}
# Example value: BBSM
${image_activate_on_success}    ${EMPTY}
# Example value: false
${image_commit_on_success}    ${EMPTY}
# Example value: false
${image_crc}    ${EMPTY}
# Example value: 0

*** Test Cases ***
Test ONU Upgrade
    [Documentation]    Validates the ONU Upgrade doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Requirement: Pass image details in following parameters in the robot command
    ...    onu_image_name, onu_image_url, onu_image_version, onu_image_crc, onu_image_local_dir
    ...    Note: The TC expects the image url and other parameters to be common for all ONUs on all BBSim
    ...    Check [VOL-3903] for more details
    [Tags]    functional   ONUUpgrade
    [Setup]    Start Logging    ONUUpgrade
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ONUUpgrade
    ...           AND             Delete All Devices and Verify
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Test ONU Upgrade Per OLT    ${bbsim_pod}    ${olt_serial_number}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

*** Keywords ***
Test ONU Upgrade Per OLT
    [Documentation]    This keyword performs the ONU Upgrade test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Download Image
        Download ONU Device Image    ${image_version}    ${image_url}    ${image_vendor}
        ...    ${image_activate_on_success}    ${image_commit_on_success}
        ...    ${image_crc}    ${onu_device_id}
        ${imageState}=    Run Keyword If    '${image_activate_on_success}'=='true'    Set Variable    IMAGE_ACTIVE
        ...    ELSE IF    '${image_activate_on_success}'=='true' and '${image_commit_on_success}'=='true'
        ...    Set Variable    IMAGE_COMMITTED
        ...    ELSE    Set Variable    IMAGE_INACTIVE
        ${activated}=    Set Variable If    '${image_activate_on_success}'=='true'    True    False
        ${committed}=    Set Variable If    '${image_activate_on_success}'=='true' and '${image_commit_on_success}'=='true'
        ...    True    False
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    ${imageState}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    ${committed}    ${activated}    True
        # Activate Image
        ${imageState}=    Set Variable If    '${image_commit_on_success}'=='true'    IMAGE_COMMITTED    IMAGE_ACTIVE
        ${committed}=    Set Variable If    '${image_commit_on_success}'=='true'    True    False
        Run Keyword If    '${image_activate_on_success}'=='false'    Run Keywords
        ...    Activate ONU Device Image    ${image_version}    ${image_commit_on_success}    ${onu_device_id}
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    ${imageState}
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    ${committed}    True    True
        # Commit Image
        Run Keyword If    '${image_commit_on_success}'=='false'    Run Keywords
        ...    Commit ONU Device Image    ${image_version}    ${onu_device_id}
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_COMMITTED
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    True    True    True
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image On BBSim    ${NAMESPACE}    ${bbsim_pod}
        ...    ${src['onu']}    software_image_committed
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
    END

Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup

Teardown Suite
    [Documentation]    Tear down steps for the suite
    Run Keyword If    ${has_dataplane}    Clean Up Linux
