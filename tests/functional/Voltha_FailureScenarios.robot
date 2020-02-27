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

*** Settings ***
Documentation     Test various failure scenarios
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

*** Test Cases ***
Verify ONU after rebooting physically
    [Documentation]    Test the ONU functionality by physically turning on/off ONU.
    ...    Prerequisite : Subscriber are authenticated/DHCP/pingable state
    ...    Test case runs only on the PODs that are configured with PowerSwitch that
    ...    controls the power off/on ONUs/OLT remotely (simulating a physical reboot)
    ...    VOL-2634
    [Tags]    functional   PowerSwitch
    [Setup]    Run Keywords    Announce Message    START TEST PowerSwitch
    ...        AND             Start Logging    PowerSwitch
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    PowerSwitch
    ...           AND             Announce Message    END TEST PowerSwitch
    # Add OLT device
    setup
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Power Switch Connection Suite    ${web_power_switch.ip}    ${web_power_switch.user}    ${web_power_switch.password}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Disable Switch Outlet    ${src['power_switch_port']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}

        Enable Switch Outlet    ${src['power_switch_port']}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Ignore Error    Collect Logs
    END
    # Deleting OLT after tests completes independently (as this test doesn't not run on each POD)
    Run Keyword If    ${has_dataplane}    Delete Device and Verify

Verify restart openolt-adapter container after VOLTHA is operational
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functional   VOL-1958   Restart-OpenOlt   released
    [Setup]    Run Keywords    Announce Message    START TEST Restart-OpenOlt
    ...        AND             Start Logging    Restart-OpenOlt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    Restart-OpenOlt
    ...           AND             Announce Message    END TEST Restart-OpenOlt
    # Add OLT device
    setup
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    ${waitforRestart}    Set Variable    120s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     adapter-open-olt
    Restart Pod    ${NAMESPACE}    ${podName}
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ${podName}    ${NAMESPACE}
    ...    Running
    Repeat Sanity Test
    Run Keyword and Ignore Error    Collect Logs
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Check OLT/ONU Authentication After Radius Pod Restart
    [Documentation]    After radius restart, triggers reassociation, checks status and
    ...    authentication, validates dhcp and ping. Note : wpa reassociate works only when
    ...    wpa supplicant is running in background hence it is recommended to remove
    ...    teardown from previous test or uncomment 'Teardown    None'.
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    RadiusRestart    released
    [Setup]    Run Keywords    Announce Message    START TEST RadiusRestart
    ...        AND             Start Logging    RadiusRestart
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RadiusRestart
    ...           AND             Announce Message    END TEST RadiusRestart
    ${waitforRestart}    Set Variable    120s
    Wait Until Keyword Succeeds    ${timeout}    15s    Restart Pod    ${NAMESPACE}    ${RESTART_POD_NAME}
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ${RESTART_POD_NAME}   ${NAMESPACE}
    ...    Running
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate Authentication After Reassociate    True    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate DHCP and Ping    True    True    ${src['dp_iface_name']}
        ...    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}
        ...    ${dst['pass']}    ${dst['container_type']}    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

Sanity E2E Test for OLT/ONU on POD With Core Fail and Restart
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    functional    rwcore-restart
    [Setup]    Run Keywords    Announce Message    START TEST RwCoreFailAndRestart
    ...        AND             Start Logging    RwCoreFailAndRestart
    ...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Collect Logs
    ...          AND             Stop Logging    RwCoreFailAndRestart
    ...          AND             Announce Message    END TEST RwCoreFailAndRestart
    ...          AND             Delete Device and Verify
    Run Keyword and Ignore Error    Collect Logs
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=omci-flows-pushed
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
    END

    # Scale down the rw-core deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment    voltha    voltha-rw-core    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pod Does Not Exist    voltha    voltha-rw-core
    # Ensure the ofagent POD goes "not-ready" as expected
    Wait Until keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-ofagent    0
    # Scale up the core deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment    voltha    voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-rw-core    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    voltha-ofagent    1
    # For some reason scaling down and up the POD behind a service causes the port forward to stop working,
    # so restart the port forwarding for the API service
    Restart VOLTHA Port Foward    voltha-api-minimal
    # Ensure that the ofagent pod is up and ready and the device is available in ONOS, this
    # represents system connectivity being restored
    Wait Until Keyword Succeeds    ${timeout}    2s    Device Is Available In ONOS
    ...    http://karaf:karaf@${k8s_node_ip}:${ONOS_REST_PORT}    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
    END

Sanity E2E Test for OLT/ONU on POD With OLT Adapters Fail and Restart
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    bbsim    olt-adapter-restart
    [Setup]    Run Keywords    Announce Message    START TEST OltAdapterRestart
    ...        AND             Start Logging    OltAdapterRestart
    ...        AND             Clear All Devices Then Create New Device
    [Teardown]   Run Keywords    Collect Logs
    ...          AND             Stop Logging    OltAdapterRestart
    ...          AND             Announce Message    END TEST OltAdapterRestart
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}

        # Bring up the device and verify it authenticates
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device        ENABLED    ACTIVE    REACHABLE
        ...    ${onu_device_id}    onu=True    onu_reason=omci-flows-pushed
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
    END
    # Scale down the open OLT adapter deployment to 0 PODs and once confirmed, scale it back to 1
    Scale K8s Deployment    voltha    adapter-open-olt    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pod Does Not Exist    voltha    adapter-open-olt
    # Scale up the open OLT adapter deployment and make sure both it and the ofagent deployment are back
    Scale K8s Deployment    voltha   adapter-open-olt    1
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Expected Available Deployment Replicas    voltha    adapter-open-olt    1

    # Ensure the device is available in ONOS, this represents system connectivity being restored
    Wait Until Keyword Succeeds    ${timeout}    2s    Device Is Available In ONOS
    ...    http://karaf:karaf@${k8s_node_ip}:${ONOS_REST_PORT}    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        # Add subscriber access and verify that DHCP completes to ensure system is still functioning properly
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
    END

Verify restart ofagent container after VOLTHA is operational
    [Documentation]    Restart ofagent container after VOLTHA is operational.
    ...    Please note this test case should be run before the restart of other containers.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functional   VOL-2409   ofagentRestart   notready
    [Setup]    Run Keywords    Announce Message    START TEST ofagentRestart
    ...        AND             Start Logging    ofagentRestart
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ofagentRestart
    ...           AND             Announce Message    END TEST ofagentRestart
    ${waitforRestart}    Set Variable    120s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Restart Pod    ${NAMESPACE}    ofagent
    Sleep    60s
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ofagent    ${NAMESPACE}
    ...    Running
    Repeat Sanity Test
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}

Check ONU adapter crash not forcing authentication again
    [Documentation]    After ONU adapter restart, checks wpa log for 'authentication started'
    ...    message count to make sure auth not started again and validates EAP status and ping.
    ...    Assuming that test1 or sanity was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    ONUAdaptCrash    notready
    [Setup]    Run Keywords    Announce Message    START TEST ONUAdaptCrash
    ...        AND             Start Logging    ONUAdaptCrash
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ONUAdaptCrash
    ...           AND             Announce Message    END TEST ONUAdaptCrash
    @{before_list}=    Create List
    @{after_list}=    Create List
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${before}=    Run Keyword If    ${has_dataplane}    Check Remote File Contents For WPA Logs
        ...    True    /tmp/wpa.log    authentication started    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Append To List    ${before_list}    ${before}
    END
    Wait Until Keyword Succeeds    ${timeout}    15s    Restart Pod    ${NAMESPACE}    adapter-open-onu
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pod Status    ${podName}    ${NAMESPACE}
    ...    Running
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${after}=    Run Keyword If    ${has_dataplane}    Check Remote File Contents For WPA Logs
        ...    True    /tmp/wpa.log    authentication started    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Append To List    ${after_list}    ${after}
        ${output}=    Run Keyword If    ${has_dataplane}    Login And Run Command On Remote System
        ...    wpa_cli status | grep SUCCESS    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Should Contain    ${output}    SUCCESS
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s    Check Ping
        ...    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}
        ...    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    Lists Should Be Equal    ${after_list}    ${before_list}
    Log    ${after_list}
    Log    ${before_list}
    Run Keyword and Ignore Error    Collect Logs

ONU Reboot
    [Documentation]    Reboot ONU and verify that ONU comes up properly
    [Tags]    VOL-1957    RebootONU   notready
    [Setup]    Run Keywords    Announce Message    START TEST RebootONU
    ...        AND             Start Logging    RebootONU
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RebootONU
    ...           AND             Announce Message    END TEST RebootONU
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Reboot ONU    ${onu_device_id}   ${src}   ${dst}
        Verify ping is succesful except for given device     ${num_onus}    ${onu_device_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify pings are successful after reboot on the current ONU
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    #Run Keyword If    ${has_dataplane}    Clean Up Linux
    #Check after reboot that ONUs are active, authenticated/DHCP/pingable
    #Perform Sanity Test

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup
