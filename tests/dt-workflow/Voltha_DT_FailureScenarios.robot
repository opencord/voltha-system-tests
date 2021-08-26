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
Verify ONU after Rebooting Physically for DT
    [Documentation]    Test the ONU functionality by physically turning on/off ONU.
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Test case runs only on the PODs that are configured with PowerSwitch that
    ...    controls the power off/on ONUs/OLT remotely (simulating a physical reboot)
    [Tags]    functionalDt    PowerSwitchOnuRebootDt    VOL-2819    PowerSwitch
    [Setup]    Start Logging    RebootOnu_PowerSwitch_Dt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    RebootOnu_PowerSwitch_Dt
    ...           AND             Delete All Devices and Verify
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    Power Switch Connection Suite    ${web_power_switch.ip}    ${web_power_switch.user}    ${web_power_switch.password}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Disable Power Switch
        Disable Switch Outlet    ${src['power_switch_port']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Remove Subscriber Access (To replicate DT workflow)
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        # Allow the remove subscriber command to clean up all the flows, schedulers and queues before deleting the device
        Sleep    5s
        # Delete ONU Device (To replicate DT workflow)
        Delete Device    ${onu_device_id}
        Sleep    5s
        # Enable Power Switch
        Enable Switch Outlet    ${src['power_switch_port']}
        # Waiting extra time for the ONU to come up
        Sleep    60s
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify UNI Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        #Run Keyword If    ${has_dataplane}    Clean Up Linux
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END
    # Verify flows for all OLTs
    Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate All OLT Flows

Verify OLT after Rebooting Physically for DT
    [Documentation]    Test the physical reboot of the OLT
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Test performs a physical reboot, performs "reboot" from the OLT CLI
    [Tags]    functionalDt   PhysicalOltRebootDt   VOL-2817
    [Setup]    Start Logging    RebootOlt_Physical_Dt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    RebootOlt_Physical_Dt
    ...           AND             Delete All Devices and Verify
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    # Reboot the OLT from the OLT CLI
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Run Keyword If    ${has_dataplane}    Login And Run Command On Remote System
        ...    reboot    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}   prompt=#
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Wait for the OLT to come back up
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s
        ...    Check Remote System Reachability    True    ${olt_ssh_ip}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
    END
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT

Verify restart openonu-adapter container after subscriber provisioning for DT
    [Documentation]    Restart openonu-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functionalDt   Restart-OpenOnu-Dt    soak
    [Setup]    Start Logging    Restart-OpenOnu-Dt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOnu-Dt
    # Add OLT device
    Run Keyword If    '${SOAK_TEST}'=='False'    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBeforeRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     adapter-open-onu
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    # Wait for 1 min after openonu adapter is restarted
    Sleep    60s
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBeforeRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully
    Run Keyword If    '${SOAK_TEST}'=='False'    Delete All Devices and Verify

Verify restart openolt-adapter container after subscriber provisioning for DT
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functionalDt   Restart-OpenOlt-Dt    soak
    [Setup]    Start Logging    Restart-OpenOlt-Dt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOlt-Dt
    # Add OLT device
    Run Keyword If    '${SOAK_TEST}'=='False'    setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     ${OLT_ADAPTER_APP_LABEL}
    Wait Until Keyword Succeeds    ${timeout}    15s    Delete K8s Pods By Label    ${NAMESPACE}    app    ${podName}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pods Status By Label    ${NAMESPACE}
    ...    app    ${podName}    Running
    # Wait for 1 min after openolt adapter is restarted
    Sleep    60s
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Verify openolt adapter restart before subscriber provisioning for DT
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    functionalDt    olt-adapter-restart-Dt    soak
    [Setup]    Start Logging    OltAdapterRestart-Dt
    #...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...          AND             Stop Logging    OltAdapterRestart-Dt
    # Add OLT and perform sanity test
    #setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    #Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Set Global Variable    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    360s    5s    Validate Device        ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=omci-flows-pushed    by_dev_id=True
    END
    # Scale down the open OLT adapter deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment by Pod Label    ${NAMESPACE}    app    ${OLT_ADAPTER_APP_LABEL}    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pods Do Not Exist By Label    ${NAMESPACE}    app
    ...    ${OLT_ADAPTER_APP_LABEL}
    # Scale up the open OLT adapter deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment by Pod Label    ${NAMESPACE}    app    ${OLT_ADAPTER_APP_LABEL}    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas By Pod Label     ${NAMESPACE}    app    ${OLT_ADAPTER_APP_LABEL}    1

    # Ensure the device is available in ONOS, this represents system connectivity being restored
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
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END

Verify restart ofagent container after subscriber is provisioned for DT
    [Documentation]    Restart ofagent container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functionalDt   ofagentRestart-Dt    soak
    [Setup]    Start Logging    ofagentRestart-Dt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    ofagentRestart-Dt
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
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
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
        ...    Verify UNI Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        # Verify Ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Check Ping    True
        ...    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Scale Up the Of-Agent Deployment
    Scale K8s Deployment    ${NAMESPACE}    voltha-voltha-ofagent    1
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ofagent    ${NAMESPACE}
    ...    Running
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Sanity E2E Test for OLT/ONU on POD With Core Fail and Restart for DT
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    functionalDt    rwcore-restart-Dt
    [Setup]    Run Keywords    Start Logging    RwCoreFailAndRestart-Dt
    ...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...          AND             Stop Logging    RwCoreFailAndRestart-Dt
    #...          AND             Delete Device and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get NNI Port in ONOS    ${of_id}
       # Set Global Variable    ${nni_port}
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
        ...    ${onu_device_id}    onu=True    onu_reason=initial-mib-downloaded    by_dev_id=True
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
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END

Verify OLT Soft Reboot for DT
    [Documentation]    Test soft reboot of the OLT using voltctl command
    [Tags]    VOL-2818   OLTSoftRebootDt    functionalDt
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
        Reboot Device    ${olt_device_id}
        # Wait for the OLT to actually go down
        Wait Until Keyword Succeeds    360s    5s    Validate OLT Device    ENABLED    UNKNOWN    UNREACHABLE
        ...    ${olt_serial_number}
    END
    #Verify that ping fails
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
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
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
    END
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    #Check after reboot that ONUs are active, DHCP/pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT

Verify ONU Soft Reboot for DT
    [Documentation]    Test soft reboot of the ONU using voltctl command
    [Tags]    VOL-2820    ONUSoftRebootDt   notready
    [Setup]    Start Logging    ONUSoftRebootDt
    #...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ONUSoftRebootDt
    #...           AND             Delete Device and Verify
    #Reboot the ONU and verify that ping fails
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Reboot Device    ${onu_device_id}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Verify ping is succesful except for given device     ${num_onus}    ${onu_device_id}
        # Remove Subscriber Access (To replicate DT workflow)
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
	# Delete ONU Device (To replicate DT workflow)
        Delete Device    ${onu_device_id}
        Sleep    40s
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify UNI Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        #Run Keyword If    ${has_dataplane}    Clean Up Linux
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END
    # Verify ONOS Flows
    # Number of Access Flows on ONOS equals 4 * the Number of Active ONUs (2 for each downstream and upstream)
    ${onos_flows_count}=    Evaluate    4 * ${num_onus}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Subscriber Access Flows Added Count DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    ${of_id}    ${onos_flows_count}
    # Verify VOLTHA Flows
    # Number of per OLT Flows equals Twice the Number of Active ONUs (each for downstream and upstream) + 1 for LLDP
    ${olt_flows}=    Evaluate    2 * ${num_onus} + 1
    # Number of per ONU Flows equals 2 (one each for downstream and upstream)
    ${onu_flows}=    Set Variable    2
    Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows    ${olt_flows}
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Log    ${List_ONU_Serial}
    Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONU Flows
    ...    ${List_ONU_Serial}    ${onu_flows}

Verify restart openonu-adapter container while continuously running ping in background for DT
    [Documentation]    Restart openonu-adapter container after VOLTHA is operational.
    ...    Run the ping continuously in background during container restart,
    ...    and verify that there should be no affect on the dataplane.
    [Tags]    functionalDt    RestartOpenOnuPingDt    non-critical
    [Setup]    Start Logging    RestartOpenOnuPingDt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    RestartOpenOnuPingDt
    Clear All Devices Then Create New Device
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
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
    Sleep    60s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBeforeRestart}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Stop Ping Running In Background    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        ${ping_output}=    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Retrieve Remote File Contents    ${ping_output_file}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Check Ping Result    True    ${ping_output}
    END

Verify restart openolt-adapter container while continuously running ping in background for DT
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    ...    Run the ping continuously in background during container restart,
    ...    and verify that there should be no affect on the dataplane.
    [Tags]    functionalDt    RestartOpenOltPingDt    non-critical
    [Setup]    Start Logging    RestartOpenOltPingDt
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    RestartOpenOltPingDt
    Clear All Devices Then Create New Device
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
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
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Stop Ping Running In Background    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${ping_output_file}=    Set Variable    /tmp/${src['onu']}_ping
        ${ping_output}=    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Retrieve Remote File Contents    ${ping_output_file}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Check Ping Result    True    ${ping_output}
    END

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

