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
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanity    test1
    [Setup]    Run Keywords    Announce Message    START TEST SanityTest
    ...        AND             Start Logging    SanityTest
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTest
    ...           AND             Announce Message    END TEST SanityTest
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test Disable and Enable OLT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the OLT and validate that the pings do not succeed
    ...    Perform enable on the OLT and validate that the pings are successful
    [Tags]    VOL-2410    DisableEnableOLT    notready
    [Setup]    Run Keywords    Announce Message    START TEST DisableEnableOLT
    ...        AND             Start Logging    DisableEnableOLT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableOLT
    ...           AND             Announce Message    END TEST DisableEnableOLT
    #Disable the OLT and verify the OLT/ONUs are disabled properly
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ENABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=false
        #Verify that ping fails
        Run Keyword If    ${has_dataplane}
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}}
    END
    #Enable the OLT back and check ONU, OLT status are back to "ACTIVE"
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        #Verify that ping workss fine again
        Run Keyword If    ${has_dataplane}
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}}
        Run Keyword and Ignore Error   Collect Logs
    END


Test Disable and Enable ONU
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs and validate that the pings do not succeed
    ...    Perform enable on the ONUs and validate that the pings are successful
    [Tags]    functional    DisableEnableONU    released
    [Setup]    Run Keywords    Announce Message    START TEST DisableEnableONU
    ...        AND             Start Logging    DisableEnableONU
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableONU
    ...           AND             Announce Message    END TEST DisableEnableONU
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    20s    2s    Test Devices Disabled in VOLTHA    Id=${onu_device_id}
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

Test Subscriber Delete and Add
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are authenticated/DHCP/pingable
    ...    Delete a subscriber and validate that the pings do not succeed
    ...    Re-add the subscriber and validate that the pings are successful
    [Tags]    functional    SubAddDelete    released
    [Setup]    Run Keywords    Announce Message    START TEST SubAddDelete
    ...        AND             Start Logging     SubAddDelete
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SubAddDelete
    ...           AND             Announce Message    END TEST SubAddDelete
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

Check DHCP attempt fails when subscriber is not added
    [Documentation]    Validates when removed subscriber access, DHCP attempt, ping fails and
    ...    when again added subscriber access, DHCP attempt, ping succeeds
    ...    Assuming that test1 or sanity test was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    SubsRemoveDHCP    released
    [Setup]    Run Keywords    Announce Message    START TEST SubsRemoveDHCP
    ...        AND             Start Logging    SubsRemoveDHCP
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SubsRemoveDHCP
    ...           AND             Announce Message    END TEST SubsRemoveDHCP
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
        Sleep    15s
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

Test Disable and Enable ONU scenario for ATT workflow
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs, call volt-remove-subscriber and validate that the pings do not succeed
    ...    Perform enable on the ONUs, authentication check, volt-add-subscriber-access and
    ...    validate that the pings are successful
    ...    VOL-2284
    [Tags]    functional    ATT_DisableEnableONU    released
    [Setup]    Run Keywords    Announce Message    START TEST ATT_DisableEnableONU
    ...        AND             Start Logging    ATT_DisableEnableONU
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ATT_DisableEnableONU
    ...           AND             Announce Message    END TEST ATT_DisableEnableONU
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
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

Delete OLT, ReAdd OLT and Perform Sanity Test
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Disable and Delete the OLT
    ...    Create/Enable the same OLT again
    ...    Validate authentication/DHCP/E2E pings succeed for all the ONUs connected to the OLT
    [Tags]    functional    DeleteOLT    released
    [Setup]    Run Keywords    Announce Message    START TEST DeleteOLT
    ...        AND             Start Logging    DeleteOLT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DeleteOLT
    ...           AND             Announce Message    END TEST DeleteOLT
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${has_dataplane}    Delete Device and Verify
    Run Keyword and Ignore Error    Collect Logs
    # Recreate the OLT
    Run Keyword If    ${has_dataplane}    Setup
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test

Test disable ONUs and OLT then delete ONUs and OLT
    [Documentation]    On deployed POD, disable the ONU, disable the OLT and then delete ONU and OLT.
    ...    This TC is to confirm that ONU removal is not impacting OLT
    ...    Devices will be removed during the execution of this TC
    ...    so calling setup at the end to add the devices back to avoid the confusion.
    [Tags]    functional    VOL-2354    DisableDeleteONUandOLT    released
    [Setup]    Run Keywords    Announce Message    START TEST DisableDeleteONUandOLT
    ...        AND             Start Logging    DisableDeleteONUandOLT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableDeleteONUandOLT
    ...           AND             Announce Message    END TEST DisableDeleteONUandOLT
    ${olt_device_id}=    Get Device ID From SN    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl device disable ${onu_device_id}
        Should Be Equal As Integers    ${rc}    0
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=false
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
    END
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=false
        ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${onu_device_id}
        Should Be Equal As Integers    ${rc}    0
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${olt_serial_number}
    END
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Test Empty Device List

Validate authentication on a disabled ONU
    [Documentation]    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs and validate that the authentication do not succeed
    ...    Perform enable on the ONUs and validate that authentication successful
    [Tags]    functional    DisableONU_AuthCheck
    # Creates Devices in the Setup
    [Setup]    Run Keywords    Announce Message    START TEST DisableDeleteONUandOLT
    ...        AND             Start Logging    DisableONU_AuthCheck
    ...        AND    Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableONU_AuthCheck
    ...           AND             Announce Message    END TEST DisableONU_AuthCheck
    ...           AND             Delete Device and Verify
    Run Keyword and Ignore Error    Collect Logs
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    Clean WPA Process
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword and Ignore Error    Collect Logs
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=false
        ${wpa_log}=    Run Keyword If    ${has_dataplane}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    False
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Enable Device    ${onu_device_id}
        Run Keyword And Ignore Error    Kill Linux Process    [w]pa_supplicant    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error    Collect Logs
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
    END
    Run Keyword and Ignore Error    Collect Logs


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

