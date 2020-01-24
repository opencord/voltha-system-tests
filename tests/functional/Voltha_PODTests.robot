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
${external_libs}    True
${teardown_device}    False
${scripts}        ../../scripts

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanity    test1
    [Teardown]    NONE
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Run Keyword and Ignore Error    Collect Logs

Test Disable and Enable ONU
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs and validate that the pings do not succeed
    ...    Perform enable on the ONUs and validate that the pings are successful
    [Tags]    functional    DisableEnableONU    released
    [Setup]    None
    [Teardown]    None
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        #Test Devices Disabled in VOLTHA    Id=${onu_device_id}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Enable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END
    Run Keyword and Ignore Error    Collect Logs

Test Subscriber Delete and Add
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are authenticated/DHCP/pingable
    ...    Delete a subscriber and validate that the pings do not succeed
    ...    Re-add the subscriber and validate that the pings are successful
    [Tags]    functional    SubAddDelete    released
    [Setup]    None
    [Teardown]    None
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END
    Run Keyword and Ignore Error    Collect Logs

Check DHCP attempt fails when subscriber is not added
    [Documentation]    Validates when removed subscriber access, DHCP attempt, ping fails and
    ...    when again added subscriber access, DHCP attempt, ping succeeds
    ...    Assuming that test1 or sanity test was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    SubsRemoveDHCP    released
    [Setup]    None
    [Teardown]    None
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Run Keyword And Ignore Error    Login And Run Command On Remote System    killall dhclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Ignore Error    Login And Run Command On Remote System    ps -ef | grep dhclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Sleep    5s
        Run Keyword And Ignore Error    Login And Run Command On Remote System    ps -ef | grep dhclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Delete IP Addresses from Interface on Remote Host    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Ignore Error    Login And Run Command On Remote System
        ...    ifconfig | grep -A 10 ens    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    False
        ...    False    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword and Ignore Error    Collect Logs
    END
    Run Keyword and Ignore Error    Collect Logs

Test Disable and Enable ONU scenario for ATT workflow
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs, call volt-remove-subscriber and validate that the pings do not succeed
    ...    Perform enable on the ONUs, authentication check, volt-add-subscriber-access and
    ...    validate that the pings are successful
    ...    VOL-2284
    [Tags]    functional    ATT_DisableEnableONU
    [Setup]    None
    #[Teardown]    None
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        Sleep    5s
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s    Check Ping
        ...    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ELSE    sleep    60s
        Enable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate Authentication After Reassociate    True
        ...    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Collect Logs
    END
    Run Keyword and Ignore Error    Collect Logs

Delete OLT, ReAdd OLT and Perform Sanity Test
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Disable and Delete the OLT
    ...    Create/Enable the same OLT again
    ...    Validate authentication/DHCP/E2E pings succeed for all the ONUs connected to the OLT
    [Tags]    functional    DeleteOLT
    [Setup]    None
    [Teardown]    NONE
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${has_dataplane}    Delete Device and Verify
    Run Keyword and Ignore Error    Collect Logs
    # Recreate the OLT
    Run Keyword If    ${has_dataplane}    Setup
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test
    Run Keyword and Ignore Error    Collect Logs

Test disable ONUs and OLT then delete ONUs and OLT
    [Documentation]    On deployed POD, disable the ONU, disable the OLT and then delete ONU and OLT.
    ...    This TC is to confirm that ONU removal is not impacting OLT
    ...    Devices will be removed during the execution of this TC
    ...    so calling setup at the end to add the devices back to avoid the confusion.
    [Tags]    VOL-2354    DisableDeleteONUandOLT    notready
    [Setup]    NONE
    [Teardown]    None
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl device disable ${onu_device_id}
        Should Be Equal As Integers    ${rc}    0
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=false
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
    END
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    DISABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=false
        ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${onu_device_id}
        Should Be Equal As Integers    ${rc}    0
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${olt_serial_number}
    END
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Test Empty Device List
    #Adding setup here to add the devices back since this TC removes the devices
    Run Keyword If    ${has_dataplane}    sleep    180s
    setup

Sanity E2E Test for OLT/ONU on POD With Core Fail and Restart
    [Documentation]    Deploys an device instance and waits for it to authenticate. After
    ...    authentication is successful the rw-core deployment is scaled to 0 instances to
    ...    simulate a POD crash. The test then scales the rw-core back to a single instance
    ...    and configures ONOS for access. The test succeeds if the device is able to
    ...    complete the DHCP sequence.
    [Tags]    bbsim    rwcore-restart
    [Setup]    Clear All Devices Then Create New Device
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
        ...    ${ONOS_SSH_PORT}    ${onu_port}
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

Collect Logs
    [Documentation]    Collect Logs from voltha and onos cli for various commands
    Run Keyword and Ignore Error    Get Device List from Voltha
    Run Keyword and Ignore Error    Get Device Output from Voltha    ${olt_device_id}
    Run Keyword and Ignore Error    Get Logical Device Output from Voltha    ${logical_id}
    Run Keyword If    ${external_libs}    Get ONOS Status    ${k8s_node_ip}

Clean Up Linux
    [Documentation]    Kill processes and clean up interfaces on src+dst servers
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword And Ignore Error    Kill Linux Process    [w]pa_supplicant    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Ignore Error    Kill Linux Process    [d]hclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Run Keyword And Ignore Error
        ...    Kill Linux Process    [d]hcpd    ${dst['ip']}    ${dst['user']}
        ...    ${dst['pass']}    ${dst['container_type']}    ${dst['container_name']}
        Delete IP Addresses from Interface on Remote Host    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Delete Interface on Remote Host
        ...    ${dst['dp_iface_name']}.${src['s_tag']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}
        ...    ${dst['container_type']}    ${dst['container_name']}
    END

