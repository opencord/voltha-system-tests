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

${suppressaddsubscriber}    True

*** Test Cases ***
Verify restart openonu-adapter container after subscriber provisioning for TT
    [Documentation]    Restart openonu-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functionalTT    Restart-OpenOnu-TT
    [Setup]    Start Logging    Restart-OpenOnu-TT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOnu-TT
    ...           AND             Delete All Devices and Verify
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBeforeRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     adapter-open-onu
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Sleep    5s
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    Wait Until Keyword Succeeds    ${timeout}    3s    Pods Are Ready By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT     ${suppressaddsubscriber}
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBeforeRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Verify restart openolt-adapter container after subscriber provisioning for TT
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    [Tags]    functionalTT    Restart-OpenOlt-TT
    [Setup]    Start Logging    Restart-OpenOlt-TT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOlt-TT
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     ${OLT_ADAPTER_APP_LABEL}
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Sleep    5s
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    Wait Until Keyword Succeeds    ${timeout}    3s    Pods Are Ready By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Verify restart ofagent container after subscriber is provisioned for TT
    [Documentation]    Restart ofagent container after VOLTHA is operational.
    [Tags]    functionalTT    ofagentRestart-TT
    [Setup]    Start Logging    ofagentRestart-TT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ofagentRestart-TT
    ...           AND             Scale K8s Deployment    ${NAMESPACE}    voltha-voltha-ofagent    1
    # set timeout value
    ${waitforRestart}    Set Variable    120s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     ofagent
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    Wait Until Keyword Succeeds    ${timeout}    3s    Pods Are Ready By Label    ${NAMESPACE}    app    ${podName}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    # Scale Down the Of-Agent Deployment
    Scale K8s Deployment    ${NAMESPACE}    voltha-voltha-ofagent    0
    Sleep    30s
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Check ONU port is Disabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        # Verify Ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Check Ping    True
        ...    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Scale Up the Of-Agent Deployment
    Scale K8s Deployment    ${NAMESPACE}    voltha-voltha-ofagent    1
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ofagent    ${NAMESPACE}
    ...    Running
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT    ${suppressaddsubscriber}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Sanity E2E Test for OLT/ONU on POD With Core Fail and Restart for TT
    [Documentation]    Deploys an device instance. After that rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    functionalTT    rwcore-restart-TT
    [Setup]    Run Keywords    Start Logging    RwCoreFailAndRestart-TT
    ...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Collect Logs
    ...          AND             Stop Logging    RwCoreFailAndRestart-TT
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get NNI Port in ONOS    ${of_id}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    360s    5s    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=initial-mib-downloaded
    END

    # Scale down the rw-core deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment    voltha    voltha-voltha-rw-core    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pod Does Not Exist    voltha    voltha-voltha-rw-core
    # Ensure the ofagent POD goes "not-ready" as expected
    Wait Until keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-voltha-ofagent    0
    # Scale up the core deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment    voltha    voltha-voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-voltha-ofagent    1
    # For some reason scaling down and up the POD behind a service causes the port forward to stop working,
    # so restart the port forwarding for the API service
    Restart VOLTHA Port Forward    voltha-api
    # Ensure that the ofagent pod is up and ready and the device is available in ONOS, this
    # represents system connectivity being restored
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Wait Until Keyword Succeeds    120s    2s    Device Is Available In ONOS
        ...    http://karaf:karaf@${ONOS_REST_IP}:${ONOS_REST_PORT}    ${of_id}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

Teardown Suite
    [Documentation]    Tear down steps for the suite
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS & then Create new devices
    # Remove all devices from voltha and onos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup
