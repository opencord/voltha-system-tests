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
${onu_image_name}    ${EMPTY}
# Example value: twsh.img
${onu_image_url}    ${EMPTY}
# Example value: http://bbsim0:50074/images/software-image.img
${onu_image_version}    ${EMPTY}
# Example value: v1.0.0
${onu_image_crc}    ${EMPTY}
# Example value: 0
${onu_image_local_dir}    ${EMPTY}
# Example value: /tmp

*** Test Cases ***
Test ONU Upgrade
    [Documentation]    Validates the ONU Upgrade doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Requirement: Pass image details in following parameters in the robot command
    ...    onu_image_name, onu_image_url, onu_image_version, onu_image_crc, onu_image_local_dir
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
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Download ONU Device Image    ${onu_device_id}    ${onu_image_name}    ${onu_image_url}    ${onu_image_version}
        ...    ${onu_image_crc}    ${onu_image_local_dir}
        # This additional pause to let image download finish on the OLT adapter
        # as the DOWNLOADED_SUCCEEDED below only indicates that the command is accepted.
        Run Keyword If    ${has_dataplane}    Sleep    12s
        ...    ELSE    Sleep    2s
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image    ${onu_device_id}
        ...    DOWNLOAD_SUCCEEDED    IMAGE_UNKNOWN    NO_ERROR
        Activate ONU Device Image    ${onu_device_id}    ${onu_image_name}    ${onu_image_version}
        ...    ${onu_image_crc}    ${onu_image_local_dir}
        # This additional pause to let image download and finish activate on the ONU (BBSim)
        # as the IMAGE_ACTIVE below is only an indication that the image is accepted for the download to the ONU (BBSim).
        Run Keyword If    ${has_dataplane}    Sleep    600s
        ...    ELSE    Sleep    180s
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image    ${onu_device_id}
        ...    DOWNLOAD_SUCCEEDED    IMAGE_ACTIVE    NO_ERROR
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
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

Teardown Suite
    [Documentation]    Tear down steps for the suite
    Run Keyword If    ${has_dataplane}    Clean Up Linux
