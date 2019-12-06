#Copyright 2017-present Open Networking Foundation
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
${NAMESPACE}   voltha
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}   radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    False

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanity    test1
    [Teardown]    NONE
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test
    Run Keyword and Ignore Error    Collect Logs

Test Disable and Enable ONU
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs and validate that the pings do not succeed
    ...    Perform enable on the ONUs and validate that the pings are successful
    [Tags]    functional    DisableEnableONU
    [Setup]    None
    [Teardown]    None

    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}

        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s    Check Ping    False    ${dst['dp_iface_ip_qinq']}    
        ...    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}   ${src['container_type']}    ${src['container_name']}
        Enable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s    Check Ping    True    ${dst['dp_iface_ip_qinq']}    
        ...    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}   ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error   Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error   Collect Logs
    END
    Run Keyword and Ignore Error   Collect Logs

Check OLT/ONU Authentication After Radius Pod Restart
    [Documentation]    After radius restart, triggers reassociation, checks status and
    ...    authentication, validates dhcp and ping. Note : wpa reassociate works only when
    ...    wpa supplicant is running in background hence it is recommended to remove
    ...    teardown from previous test or uncomment 'Teardown    None'.
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    RadiusRestart
    [Setup]   NONE
    Wait Until Keyword Succeeds    ${timeout}    15s    Restart Pod    ${NAMESPACE}    ${RESTART_POD_NAME}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}


        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication After Reassociate
        ...    True    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error   Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error   Collect Logs
    END
    Run Keyword and Ignore Error   Collect Logs

Test Disable and Enable ONU scenario for ATT workflow
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs, call volt-remove-subscriber and validate that the pings do not succeed
    ...    Perform enable on the ONUs, authentication check, volt-add-subscriber-access and validate that the pings are successful
    ...    VOL-2284
    [Tags]    functional    test4
    [Setup]    None
    #[Teardown]    None

    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}

        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s    Check Ping    False    ${dst['dp_iface_ip_qinq']}
        ...    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}   ${src['container_type']}    ${src['container_name']}
	...    ELSE    sleep    60s
        Enable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication After Reassociate
        ...    True    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s    Check Ping    True    ${dst['dp_iface_ip_qinq']}
        ...    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}   ${src['container_type']}    ${src['container_name']}
    END

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup

Setup
    [Documentation]    Pre-test Setup
    #test for empty device list
    ${length}=    Test Empty Device List
    Should Be Equal As Integers  ${length}     0
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    ...    ${EMPTY}    ${olt_device_id}
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}

Teardown
    [Documentation]    kills processes and cleans up interfaces on src+dst servers
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${external_libs}    Log Kubernetes Containers Logs Since Time    ${datetime}    ${container_list}

Collect Logs
    [Documentation]    Collect Logs from voltha and onos cli for various commands
    Run Keyword and Ignore Error    Get Device List from Voltha
    Run Keyword and Ignore Error    Get Device Output from Voltha    ${olt_device_id}
    Run Keyword and Ignore Error    Get Logical Device Output from Voltha    ${logical_id}
    Run Keyword If    ${external_libs}    Get ONOS Status    ${k8s_node_ip}

Teardown Suite
    [Documentation]    Clean up device if desired
    Run Keyword If    ${teardown_device}    Delete Device and Verify
    ${length}=    Run Keyword If    ${teardown_device}    Test Empty Device List
    Run Keyword If    ${teardown_device}    Should Be Equal As Integers    ${length}    0
    Run Keyword If    ${teardown_device}    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
    ...    device-remove ${of_id}


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

Delete Device and Verify
    [Documentation]    Disable -> Delete devices via voltctl and verify its removed
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed    ${olt_device_id}

Perform Sanity Test
    [Documentation]    This keyword performs Sanity Test Procedure
    ...    Sanity test performs authentication, dhcp and pings for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.

    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}

    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}

        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device        ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed

        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}     ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error   Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error   Collect Logs
    END
