# Copyright 2017-2024 Open Networking Foundation (ONF) and the ONF Contributors
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

# Tests can be enabled by passing the following tags:
# - [setup] Creates and enable the OLT devices
# - [activation] Checks that ONUs are active in VOLTHA and ports discevered in ONOS
# - [flow-before] Checks that flows are pushed (before subscriber provisioning)
# - [authentication] Checks that subscribers are correctly authenticated
# - [provision] Provision the data-plane flows for all the subscribers
# - [flow-after] Checks that flows are pushed (after subscriber provisioning)
# - [dhcp] Checks that subscribers have received an IP
#
# To run the full test:
#   robot Voltha_Scale_Tests.robot
#
# To run only ceratain tests:
#   robot -i activation -i flow-before Voltha_Scale_Tests.robot
#
# To exclude only ceratain tests:
#   robot -e -i flow-before Voltha_Scale_Tests.robot
#
# Once te test complete you can extrapolate the results by using
#   python extract-times.py

*** Settings ***
Documentation     Collect measurements on VOLTHA performances
Suite Setup       Setup Suite
#Test Setup        Setup
#Test Teardown     Teardown
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
Resource          ../../libraries/flows.robot
Resource          ../../libraries/k8s.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/bbsim.robot
Resource          ../../variables/variables.robot

*** Variables ***
${ONOS_SSH_IP}  127.0.0.1
${ONOS_SSH_PORT}    30115
${ONOS_REST_IP}  127.0.0.1
${ONOS_REST_PORT}    30120

${BBSIM_REST_IP}    127.0.0.1
${BBSIM_REST_PORT}    50071

${NAMESPACE}      default

# Scale pipeline values
${stackId}  1
${olt}  1
${pon}  1
${onu}  1

${enableFlowProvisioning}   true
${enableSubscriberProvisioning}     true

${workflow}     att
${withEapol}    false
${withDhcp}    false
${withIgmp}    false
# as of now the LLDP flow is always installed
${withLLDP}   true

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

${timeout}    10m

# ONU Image to test for Upgrade needs to be passed in the following format:
${image_version}    BBSM_IMG_00002
${image_url}    http://bbsim0:50074/images/software-image.img
${image_vendor}    BBSM
${image_activate_on_success}    false
${image_commit_on_success}    false
${image_crc}    0

*** Test Cases ***

Create and Enable devices
    [Documentation]  Create and enable the OLTs in VOLTHA
    [Tags]      setup
    ${olt_device_ids}=      Create List
    FOR    ${INDEX}    IN RANGE    0    ${olt}
        ${olt_device_id}=    Create Device  bbsim${INDEX}     50060     openolt
        Enable Device    ${olt_device_id}
        Append To List  ${olt_device_ids}    ${olt_device_id}
    END

    Set Suite Variable    ${olt_device_ids}

OLTs in ONOS
    [Documentation]  Check that ONOS recognize the correct number of OLTs
    [Tags]  activation  plot-onos-olts
    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Wait for Olt in ONOS   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${deviceId}
    END

Onu Activation in VOLTHA
    [Documentation]    Check that all ONUs reach the ACTIVE/ENABLED state in VOLTHA
    [Tags]      activation    plot-voltha-onus
    Wait For ONUs In VOLTHA     ${total_onus}    ${timeout}

Port Discovery in ONOS
    [Documentation]    Check that all the UNI ports show up in ONOS
    [Tags]      activation    plot-onos-ports
    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Wait for Ports in ONOS      ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus_per_olt}   ${deviceId}     BBSM
    END

Flows validation in VOLTHA before subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]      flow-before   plot-voltha-flows-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true    Flow provisioning is not enabled
    Wait for Logical Devices flows   ${workflow}    ${total_onus}    ${olt}    false
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}    ${timeout}

Flows validation in VOLTHA Adapters before subscriber provisioning
    [Documentation]  Check that all flows has been store in devices of type openolt
    [Tags]      flow-before   plot-voltha-openolt-flows-before  only-me
    Should Be Equal   ${enableFlowProvisioning}     true    Flow provisioning is not enabled
    Wait for OpenOLT Devices flows   ${workflow}    ${total_onus}    ${olt}    false
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in ONOS before subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]      flow-before   plot-onos-flows-before
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true    Flow provisioning is not enabled

    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Wait for all flows to in ADDED state    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...     ${deviceId}     ${workflow}    ${total_onus_per_olt}    1    false
        ...     ${withEapol}    ${withDhcp}     ${withIgmp}   ${withLLDP}
    END

Wait for subscribers to be Authenticated
    [Documentation]    Check that all subscribers have successfully authenticated
    [Tags]      authentication    plot-onos-auth

    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Wait for AAA Authentication     ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus_per_olt}   ${deviceId}
    END

Image Download and Validation during ONUs Software Upgrade
    [Documentation]    Validates the Download Image step in ONU Upgrade process
    ...    Requirement: Pass image details in following parameters in the robot command
    ...    onu_image_name, onu_image_url, onu_image_version, onu_image_crc, onu_image_local_dir
    ...    Note: Expects the image url and other parameters to be common for all ONUs on all BBSim
    [Tags]    onu-upgrade    onu-upgrade-image-download
    @{list_onu_device_id}=    Create List
    ${list_onu_device_id}=    Get ONUs Device IDs from Voltha
    ${onu_device_id_str}=    Catenate    @{list_onu_device_id}
    Download ONU Device Image    ${image_version}    ${image_url}    ${image_vendor}
    ...    ${image_activate_on_success}    ${image_commit_on_success}
    ...    ${image_crc}    ${onu_device_id_str}
    ${imageState}=    Run Keyword If    '${image_activate_on_success}'=='true' and '${image_commit_on_success}'=='false'
    ...    Set Variable    IMAGE_ACTIVE
    ...    ELSE IF    '${image_activate_on_success}'=='true' and '${image_commit_on_success}'=='true'
    ...    Set Variable    IMAGE_COMMITTED
    ...    ELSE    Set Variable    IMAGE_INACTIVE
    ${activated}=    Set Variable If    '${image_activate_on_success}'=='true'    True    False
    ${committed}=    Set Variable If    '${image_activate_on_success}'=='true' and '${image_commit_on_success}'=='true'
    ...    True    False
    Wait for ONUs Image Status in VOLTHA    ${total_onus}    ${image_version}    DOWNLOAD_SUCCEEDED    NO_ERROR    ${imageState}
    ...    ${timeout}
    FOR    ${onu_device_id}    IN    @{list_onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    10s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    ${committed}    ${activated}    True
    END

Image Activation and Validation during ONUs Software Upgrade
    [Documentation]    Validates the Activate Image step in ONU Upgrade process
    ...    Requirement: Pass image details in following parameters in the robot command
    ...    onu_image_name, onu_image_url, onu_image_version, onu_image_crc, onu_image_local_dir
    ...    Note: Expects the image url and other parameters to be common for all ONUs on all BBSim
    [Tags]    onu-upgrade    onu-upgrade-image-activate
    Pass Execution If    '${image_activate_on_success}'=='true'    Skipping test: Image activated in download stage
    @{list_onu_device_id}=    Create List
    ${list_onu_device_id}=    Get ONUs Device IDs from Voltha
    ${onu_device_id_str}=    Catenate    @{list_onu_device_id}
    Activate ONU Device Image    ${image_version}    ${image_commit_on_success}    ${onu_device_id_str}
    ${imageState}=    Set Variable If    '${image_commit_on_success}'=='true'    IMAGE_COMMITTED    IMAGE_ACTIVE
    ${committed}=    Set Variable If    '${image_commit_on_success}'=='true'    True    False
    Wait for ONUs Image Status in VOLTHA    ${total_onus}    ${image_version}    DOWNLOAD_SUCCEEDED    NO_ERROR    ${imageState}
    ...    ${timeout}
    FOR    ${onu_device_id}    IN    @{list_onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    10s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    ${committed}    True    True
    END

Image Commit and Validation during ONUs Software Upgrade
    [Documentation]    Validates the Commit Image step in ONU Upgrade process
    ...    Requirement: Pass image details in following parameters in the robot command
    ...    onu_image_name, onu_image_url, onu_image_version, onu_image_crc, onu_image_local_dir
    ...    Note: Expects the image url and other parameters to be common for all ONUs on all BBSim
    [Tags]    onu-upgrade    onu-upgrade-image-commit
    Pass Execution If    '${image_commit_on_success}'=='true'    Skipping test: Image committed in download or activate stage
    @{list_onu_device_id}=    Create List
    ${list_onu_device_id}=    Get ONUs Device IDs from Voltha
    ${onu_device_id_str}=    Catenate    @{list_onu_device_id}
    Commit ONU Device Image    ${image_version}    ${onu_device_id_str}
    Wait for ONUs Image Status in VOLTHA    ${total_onus}    ${image_version}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_COMMITTED
    ...    ${timeout}
    FOR    ${onu_device_id}    IN    @{list_onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    10s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    True    True    True
    END

Provision subscribers
    [Documentation]    Provision data plane flows for all the subscribers
    [Tags]      provision
    Should Be Equal   ${enableSubscriberProvisioning}     true      Subscriber provisioning is not enabled
    ${onos_devices}=    Compute Device IDs
    FOR     ${olt}  IN  @{onos_devices}
        Provision all subscribers on device  ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${ONOS_SSH_IP}    ${ONOS_REST_PORT}  ${olt}
    END

Flows validation in VOLTHA after subscriber provisioning
    [Documentation]    Check that all the flows has been stored in the logical device
    [Tags]      flow-after    plot-voltha-flows-after
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true    Flow provisioning is not enabled

    Wait for Logical Devices flows   ${workflow}    ${total_onus}    ${olt}    true
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}    ${timeout}

Flows validation in VOLTHA Adapters after subscriber provisioning
    [Documentation]  Check that all flows has been store in devices of type openolt
    [Tags]      flow-after   plot-voltha-openolt-flows-after    only-me
    Should Be Equal   ${enableFlowProvisioning}     true    Flow provisioning is not enabled
    Wait for OpenOLT Devices flows   ${workflow}    ${total_onus}    ${olt}    true
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLLDP}

Flows validation in ONOS after subscriber provisioning
    [Documentation]    Check that all the flows has been acknowledged
    [Tags]      flow-after    plot-onos-flows-after
    # NOTE fail the test immediately if we're trying to check flows without provisioning them
    Should Be Equal   ${enableFlowProvisioning}     true    Flow provisioning is not enabled

    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Wait for all flows to in ADDED state    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...     ${deviceId}     ${workflow}    ${total_onus_per_olt}    1    true
        ...     ${withEapol}    ${withDhcp}     ${withIgmp}   ${withLLDP}
    END

Wait for subscribers to have an IP
    [Documentation]    Check that all subscribers have received a DHCP_ACK
    [Tags]      dhcp  plot-onos-dhcp
    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Wait for DHCP Ack     ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${total_onus_per_olt}     ${workflow}     ${deviceId}
    END

Perform Igmp Join
    [Documentation]    Performs Igmp Join for all the ONUs of all the OLTs (based on Rest Endpoint)
    [Tags]    non-critical    igmp    igmp-join
    FOR    ${INDEX}    IN RANGE    0    ${olt}
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${INDEX}
        ${bbsim_rel_local_port}=    Evaluate    ${BBSIM_REST_PORT}+${INDEX}
        Create Session    ${bbsim_rel}    http://${BBSIM_REST_IP}:${bbsim_rel_local_port}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        ${onu_list}=    Get ONUs List    ${NAMESPACE}    ${bbsim_pod}
        Perform Igmp Join or Leave Per OLT    ${bbsim_rel}    ${onu_list}    join
        List Service    ${NAMESPACE}    ${bbsim_pod}
    END

Wait for ONUs Join Igmp Group
    [Documentation]    Checks the ONUs Join the IGMP Group
    ...    Note: Currently, it expects all the ONUs on an OLT joined the same group
    [Tags]    non-critical    igmp    igmp-join    igmp-count-verify    igmp-join-count-verify
    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify ONUs in Group Count in ONOS    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${total_onus_per_olt}    ${deviceId}
    END

Perform Igmp Leave
    [Documentation]    Performs Igmp Leave for all the ONUs of all the OLTs (based on Rest Endpoint)
    [Tags]    non-critical    igmp    igmp-leave
    FOR    ${INDEX}    IN RANGE    0    ${olt}
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${INDEX}
        ${bbsim_rel_local_port}=    Evaluate    ${BBSIM_REST_PORT}+${INDEX}
        Create Session    ${bbsim_rel}    http://${BBSIM_REST_IP}:${bbsim_rel_local_port}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        ${onu_list}=    Get ONUs List    ${NAMESPACE}    ${bbsim_pod}
        Perform Igmp Join or Leave Per OLT    ${bbsim_rel}    ${onu_list}    leave
        List Service    ${NAMESPACE}    ${bbsim_pod}
    END

Wait for ONUs Leave Igmp Group
    [Documentation]    Checks the ONUs Leave the IGMP Group
    ...    Note: Currently, it expects all the ONUs on an OLT left the same group
    [Tags]    non-critical    igmp    igmp-leave    igmp-count-verify    igmp-leave-count-verify
    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Empty Group in ONOS    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${deviceId}
    END

Disable and Delete devices
    [Documentation]  Disable and delete the OLTs in VOLTHA
    [Tags]      non-critical    teardown

    ${rc}    ${output}=     Run And Return Rc And Output    voltctl -c ${VOLTCTL_CONFIG} device list -m 32MB -f Type=openolt -q
    Should Be Equal As Integers    ${rc}    0   Failed to get device list from voltctl: ${output}
    Log     ${output}
    ${devices}=     Split To Lines  ${output}
    Log     ${devices}

    FOR     ${id}   IN  @{devices}
        Disable Device  ${id}
        Delete Device  ${id}
    END

    ${onos_devices}=    Compute Device IDs
    FOR     ${deviceId}     IN  @{onos_devices}
        Wait for all flows to be removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  ${deviceId}
    END

*** Keywords ***
Setup Suite
    [Documentation]    Setup test global variables, open an SSH connection to ONOS and starts a timer
    Set Suite Variable    ${KUBECTL_CONFIG}    %{KUBECONFIG}
    Set Suite Variable    ${VOLTCTL_CONFIG}    %{VOLTCONFIG}

    ${total_onus}=   Evaluate    ${olt} * ${pon} * ${onu}
    Set Suite Variable  ${total_onus}

    ${total_onus_per_olt}=   Evaluate    ${pon} * ${onu}
    Set Suite Variable  ${total_onus_per_olt}

    ${onos_auth}=    Create List    karaf    karaf
    Create Session    ONOS    http://${ONOS_REST_IP}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    Run Keyword If    '${workflow}'=='tt'
    ...    Send File To Onos    ${CURDIR}/../../tests/data/onos-igmp.json    apps/

Teardown Suite
   [Documentation]    Close the SSH connection to ONOS
    Close All ONOS SSH Connections

Compute device IDs
    [Documentation]  Creates a list of ONOS device ID based on the test configuration
    # TODO read ${olt} and ${stackid} from parameters
    ${base}=    Set Variable    of:00000a0a0a0a0a
    ${device_ids}=      Create List
    FOR    ${olt_id}    IN RANGE    0    ${olt}
        ${decimal_id}=  Catenate    SEPARATOR=  ${stackid}  ${olt_id}
        ${piece}=   Convert To Hex  ${decimal_id}  length=2    lowercase=yes
        ${id}=  Catenate    SEPARATOR=  ${base}     ${piece}
        Append To List  ${device_ids}    ${id}
    END

    [Return]    ${device_ids}

Perform Igmp Join or Leave Per OLT
    [Documentation]    Performs Igmp Join for all the ONUs of an OLT (based on Rest Endpoint)
    [Arguments]    ${bbsim_rel_session}    ${onu_list}    ${task}
    FOR    ${onu}    IN    @{onu_list}
        JoinOrLeave Igmp Rest Based    ${bbsim_rel_session}    ${onu}    0    ${task}    224.0.0.22
    END
