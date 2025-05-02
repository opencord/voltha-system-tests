# Copyright 2022-2023 Open Networking Foundation (ONF) and the ONF Contributors
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
Resource          ../../libraries/vgc.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/voltha.robot
Resource          ../../libraries/utils_vgc.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot
Resource          ../../libraries/power_switch.robot

*** Variables ***
${POD_NAME}       flex-ocp-cord
${VOLTHA_POD_NUM}    8
${NAMESPACE}      voltha
${INFRA_NAMESPACE}      default
${STACK_NAME}       voltha
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        120s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${kafka}    voltha-voltha-api
${KAFKA_PORT}    55555
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

# Flag specific to Soak Jobs
${SOAK_TEST}    False

*** Test Cases ***
Verify restart openonu-adapter container after subscriber provisioning for DT
    [Documentation]    Restart openonu-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    Restart-OpenOnu-Dt    soak    raj
    [Setup]    Start Logging    Restart-OpenOnu-Dt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOnu-Dt

    # Add OLT device

    Run Keyword If    '${SOAK_TEST}'=='False'    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBeforeRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     adapter-open-onu
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    # Wait for 1 min after openonu adapter is restarted
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBeforeRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully
    # "Once the onu adapter is restarted, it takes a bit of time for the OLT's/ONUs to reconcile, if the OLT is deleted 
    # before the ONUs are reconiled successfully there would be stale entries. This scenario is not handled in VOLTHA as 
    # of now. And there is no other to check if the reconcile has happened for all the ONUs. Due to this limitations a
    # sleep of 60s is introduced to give enough time for onu adapter to reconcile the ONUs."
    Sleep   60s
    Run Keyword If    '${SOAK_TEST}'=='False'    Delete All Devices and Verify

Verify restart openolt-adapter container after subscriber provisioning for DT
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    Restart-OpenOlt-Dt    soak    raj
    [Setup]    Start Logging    Restart-OpenOlt-Dt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOlt-Dt
    # Add OLT_device
    Run Keyword If    '${SOAK_TEST}'=='False'    setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     ${OLT_ADAPTER_APP_LABEL}
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    # Wait for 1 min after openolt adapter is restarted
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    # "Once the olt adapter is restarted, it takes a bit of time for the OLT's/ONUs to reconcile, if try to delete OLT
    # before the OLT's are reconiled successfully there would be recocile error. This scenario is not handled in VOLTHA as
    # of now. And there is no other to check if the reconcile has happened for all the OLTs. Due to this limitations a
    # sleep of 60s is introduced to give enough time for OLT adapter to reconcile the OLTs."
    Sleep   60s
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Verify openolt adapter restart before subscriber provisioning for DT
    [Documentation]    Restart openolt-adapter container before adding the subscriber.
    [Tags]    functionalDt    olt-adapter-restart-Dt    raj
    [Setup]    Start Logging    OltAdapterRestart-Dt
    [Teardown]   Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...          AND             Stop Logging    OltAdapterRestart-Dt
    # Add OLT device
    Sleep    120s
    Deactivate Subscribers In VGC
    Clear All Devices Then Create New Device
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Set Global Variable    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in VGC    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device        ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=initial-mib-downloaded    by_dev_id=True
    END
    # Scale down the open OLT adapter deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment by Pod Label    ${NAMESPACE}    app    ${OLT_ADAPTER_APP_LABEL}    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pods Do Not Exist By Label    ${NAMESPACE}    app
    ...    ${OLT_ADAPTER_APP_LABEL}
    # Scale up the open OLT adapter deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment by Pod Label    ${NAMESPACE}    app    ${OLT_ADAPTER_APP_LABEL}    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas By Pod Label     ${NAMESPACE}    app    ${OLT_ADAPTER_APP_LABEL}    1
    Wait Until Keyword Succeeds    ${timeout}    3s    Pods Are Ready By Label    ${NAMESPACE}    app    ${OLT_ADAPTER_APP_LABEL}

    # Ensure the device is available in ONOS, this represents system connectivity being restored
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        Wait Until Keyword Succeeds    120s    2s    Device Is Available In VGC
        ...    ${of_id}
    END

    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in VGC    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Add Subscriber Details    ${of_id}     ${onu_port}
        # Verify Meters in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Meters in VGC Ietf    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added for ONU DT in VGC    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    # "Once the olt adapter is restarted, it takes a bit of time for the OLT's/ONUs to reconcile, if try to delete OLT
    # before the OLT's are reconiled successfully there would be recocile error. This scenario is not handled in VOLTHA as
    # of now. And there is no other to check if the reconcile has happened for all the OLTs. Due to this limitations a
    # sleep of 60s is introduced to give enough time for OLT adapter to reconcile the OLTs."
    Sleep   60s
    END
    Deactivate Subscribers In VGC

Sanity E2E Test for OLT/ONU on POD With Core Fail and Restart for DT
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    functionalDt    rwcore-restart-Dt    raj
    [Setup]    Run Keywords    Start Logging    RwCoreFailAndRestart-Dt
    ...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...          AND             Stop Logging    RwCoreFailAndRestart-Dt
    #...          AND             Delete Device and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    360s    5s    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=initial-mib-downloaded    by_dev_id=True
    END

    # Scale down the rw-core deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment    voltha    voltha-voltha-rw-core    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pod Does Not Exist    voltha    voltha-voltha-rw-core
    # Ensure the ofagent POD goes "not-ready" as expected
    Wait Until keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-voltha-go-controller    1
    # Scale up the core deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment    voltha    voltha-voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-voltha-go-controller    1
    # For some reason scaling down and up the POD behind a service causes the port forward to stop working,
    # so restart the port forwarding for the API service
    Restart VOLTHA Port Forward    voltha-api 55555:55555
    # Ensure that the ofagent pod is up and ready and the device is available in ONOS, this
    # represents system connectivity being restored
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        Wait Until Keyword Succeeds    120s    2s    Device Is Available In VGC
        ...    ${of_id}
    END

    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}    ${src['uni_id']}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Post Request    VGC    services/${of_id}/${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added for ONU DT in VGC    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END
    Restart VOLTHA Port Forward    voltha-api
    ${port_fwd}    Start Process    kubectl -n voltha port-forward svc/${kafka} ${KAFKA_PORT}:${KAFKA_PORT} --address 0.0.0.0 &    shell=true

Verify OLT Soft Reboot for DT
    [Documentation]    Test soft reboot of the OLT using voltctl command
    [Tags]    VOL-2818   OLTSoftRebootDt    functionalDt    raj
    [Setup]    Start Logging    OLTSoftRebootDt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    OLTSoftRebootDt
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
        # Reboot the OLT using "voltctl device reboot" command
        Wait Until Keyword Succeeds    360s    5s    Reboot Device    ${olt_device_id}
        # Wait for the OLT to actually go down
        Wait Until Keyword Succeeds    360s    5s    Validate OLT Device    ENABLED    UNKNOWN    UNREACHABLE
        ...    ${olt_serial_number}
    END
    #Verify that ping fails
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Check OLT states
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]    sship
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        # Wait for the OLT to come back up
        Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s
        ...    Check Remote System Reachability    True    ${olt_ssh_ip}
        # Check OLT states
        Wait Until Keyword Succeeds    360s    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
    END
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    #Check after reboot that ONUs are active, DHCP/pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT

Verify restart openonu-adapter container for DT
    [Documentation]    Restart openonu-adapter container after VOLTHA is operational.
    ...    Run the ping continuously in background during container restart,
    ...    and verify that there should be no affect on the dataplane.
    ...    Also, verify that the voltha control plane functionality is not affected.
    [Tags]    functionalDt    RestartOpenOnuPingDt    raj
    [Setup]    Start Logging    RestartOpenOnuPingDt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    RestartOpenOnuPingDt
    Clear All Devices Then Create New Device
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Run Ping In Background    ${ping_output_file}    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBeforeRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     adapter-open-onu
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    # Wait for 1 min after openonu adapter is restarted
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBeforeRestart}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Stop Ping Running In Background    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        ${ping_output}=    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Retrieve Remote File Contents    ${ping_output_file}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Check Ping Result    True    ${ping_output}
    END
    # Verify Control Plane Functionality by Deleting and Re-adding the Subscriber
    # "Once the onu adapter is restarted, it takes a bit of time for the OLT's/ONUs to reconcile, if the OLT is deleted
    # before the ONUs are reconiled successfully there would be stale entries. This scenario is not handled in VOLTHA as
    # of now. And there is no other to check if the reconcile has happened for all the ONUs. Due to this limitations a
    # sleep of 60s is introduced to give enough time for onu adapter to reconcile the ONUs."
    Sleep   60s
    Verify Control Plane After Pod Restart DT

Verify restart openolt-adapter container for DT
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    ...    Run the ping continuously in background during container restart,
    ...    and verify that there should be no affect on the dataplane.
    ...    Also, verify that the voltha control plane functionality is not affected.
    [Tags]    functionalDt    RestartOpenOltPingDt    raj
    [Setup]    Start Logging    RestartOpenOltPingDt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    RestartOpenOltPingDt
    Clear All Devices Then Create New Device
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Run Ping In Background    ${ping_output_file}    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBeforeRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     ${OLT_ADAPTER_APP_LABEL}
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    # Wait for 1 min after openolt adapter is restarted
    Sleep    60s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBeforeRestart}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Stop Ping Running In Background    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        ${ping_output}=    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Retrieve Remote File Contents    ${ping_output_file}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Check Ping Result    True    ${ping_output}
    END
    # Verify Control Plane Functionality by Deleting and Re-adding the Subscriber
    # "Once the olt adapter is restarted, it takes a bit of time for the OLT's/ONUs to reconcile, if try to delete OLT
    # before the OLT's are reconiled successfully there would be recocile error. This scenario is not handled in VOLTHA as
    # of now. And there is no other to check if the reconcile has happened for all the OLTs. Due to this limitations a
    # sleep of 60s is introduced to give enough time for OLT adapter to reconcile the OLTs."
    Sleep   60s
    Verify Control Plane After Pod Restart DT

Verify restart rw-core container for DT
    [Documentation]    Restart rw-core container after VOLTHA is operational.
    ...    Run the ping continuously in background during container restart,
    ...    and verify that there should be no affect on the dataplane.
    ...    Also, verify that the voltha control plane functionality is not affected.
    [Tags]    functionalDt    RestartRwCorePingDt    raj
    [Setup]    Start Logging    RestartRwCorePingDt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    RestartRwCorePingDt
    Clear All Devices Then Create New Device
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Run Ping In Background    ${ping_output_file}    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBeforeRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     rw-core
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    # Wait for 1 min after rw-core is restarted
    Sleep    60s
    # For some reason scaling down and up the POD behind a service causes the port forward to stop working,
    # so restart the port forwarding for the API service
    Restart VOLTHA Port Forward    voltha-api
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBeforeRestart}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Stop Ping Running In Background    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        ${ping_output}=    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Retrieve Remote File Contents    ${ping_output_file}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Check Ping Result    True    ${ping_output}
    END
    # Verify Control Plane Functionality by Deleting and Re-adding the Subscriber
    # "Once the rw core is restarted, it takes a bit of time for the OLT's/ONUs to reconcile, if try to delete OLT
    # before the OLT's are reconiled successfully there would be recocile error. This scenario is not handled in VOLTHA as
    # of now. And there is no other to check if the reconcile has happened for all the OLTs. Due to this limitations a
    # sleep of 60s is introduced to give enough time for rw core to reconcile the OLTs."
    Sleep   60s
    ${port_fwd}    Start Process    kubectl -n voltha port-forward svc/${kafka} ${KAFKA_PORT}:${KAFKA_PORT} --address 0.0.0.0 &    shell=true
    Verify Control Plane After Pod Restart DT

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #power_switch.robot needs it to support different vendor's power switch
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    # Run Pre-test Setup for Soak Job
    # Note: As soak requirement, it expects that the devices under test are already created and enabled
    Run Keyword If    '${SOAK_TEST}'=='True'    Setup Soak


Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup

Verify Control Plane After Pod Restart DT
    [Documentation]    Verifies the control plane functionality after the voltha pod restart
    ...    by deleting and re-adding the subscriber
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get Device ID From SN    ${src['onu']}
        # Remove Subscriber Access
        Remove Subscriber Access   ${of_id}   ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Disable and Re-Enable the ONU (To replicate DT current workflow)
        # TODO: Delete and Auto-Discovery Add of ONU (not yet supported)
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}
        Enable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}
        # Add Subscriber Access
        Add Subscriber Details    ${of_id}     ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added for ONU DT in VGC    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Workaround for issue seen in VOL-4489. Keep this workaround until VOL-4489 is fixed.
        Run Keyword If    ${has_dataplane}    Reboot XGSPON ONU    ${src['olt']}    ${src['onu']}    omci-flows-pushed
        # Workaround ends here for issue seen in VOL-4489.
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
