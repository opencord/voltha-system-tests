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
${INFRA_NAMESPACE}      default
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

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

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
        Restart VOLTHA Port Forward     voltha-api
        # Static sleep to let voltctl tcp connection establish
        Sleep    5s
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


Test Voltha Components Minor Version Rolling Upgrade
    [Documentation]    Validates that the system can handle operations during software upgrade for minor versions.
    ...    Requirement: Components to test needs to be passed in robot command variable 'voltha_comps_under_test' in the format:
    ...    <comp-label>,<comp-container>,<comp-image>*<comp-label>,<comp-container>,<comp-image>*
    ...    Check [VOL-4534] for more details
    [Tags]    functional   VolthaCompMinorVerRollingUpgrade
    [Setup]    Start Logging    VolthaCompMinorVerRollingUpgrade
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    VolthaCompMinorVerRollingUpgrade
    ...           AND             Delete All Devices and Verify
    # Add OLT device
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Wait Until Keyword Succeeds    ${timeout}    2s    Device Is Available In ONOS
        ...    http://karaf:karaf@${ONOS_REST_IP}:${ONOS_REST_PORT}    ${of_id}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        # Check ONU port is Enabled in ONOS
        Wait Until Keyword Succeeds   120s   2s
        ...    Verify UNI Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Default Meter Present in ONOS    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${of_id}    ${onu_port}
        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device        ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=omci-flows-pushed    by_dev_id=True
        ${wpa_log}=    Run Keyword If    ${has_dataplane}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
    END
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
        # Static sleep to let image-update progress before initiating subscriber-add system-operation
        Sleep    10s
        Provision Subscribers
        Wait Until Keyword Succeeds    ${timeout}    3s    Validate Pods Status By Label    ${NAMESPACE}
        ...    app    ${label}    Running
        Wait Until Keyword Succeeds    ${timeout}    3s    Pods Are Ready By Label    ${NAMESPACE}    app    ${label}
        Wait Until Keyword Succeeds    ${timeout}    3s    Verify Pod Image    ${NAMESPACE}    app    ${label}    ${image}
        ${pod_image_1}    ${app_ver_1}    ${helm_chart_1}    Get Pod Image And App Version And Helm Chart By Label
        ...    ${NAMESPACE}    app    ${label}
        Log    ${label}: image, app ver & helm chart after upgrade: ${pod_image_1}, ${app_ver_1} & ${helm_chart_1}
        Restart VOLTHA Port Forward     voltha-api
        # Static sleep to let voltctl tcp connection establish
        Sleep    5s
        Verify Provisioned Subscribers
        Unprovision Subscribers
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
    Close All ONOS SSH Connections

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

Provision Subscribers
    [Documentation]    This keyword provisions/adds all the subscribers on all the devices
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
    END

Verify Provisioned Subscribers
    [Documentation]    This keyword verifies all the subscribers on all the devices
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in ONOS    ${of_id}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

Unprovision Subscribers
    [Documentation]    This keyword unprovisions/deletes all the subscribers on all the devices
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in ONOS    ${of_id}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ELSE    Sleep    15s
    END
# [EOF] - delta:force
