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

# For dataplane bandwidth testing
${upper_margin_pct}      105     # Allow 5% over the limit
${lower_margin_pct}      92      # Allow 8% under the limit
${udp_rate_multiplier}   1.10    # Send UDP at bw profile limit * rate_multiplier
${udp_packet_bytes}      1400    # UDP payload in bytes

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanity    test1
    [Setup]    Run Keywords    Start Logging    SanityTest
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTest
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test Disable and Enable OLT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the OLT and validate that the pings do not succeed
    ...    Perform enable on the OLT and validate that the pings are successful
    [Tags]    functional    VOL-2410    DisableEnableOLT    notready
    [Setup]    Start Logging    DisableEnableOLT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableOLT
    #Disable the OLT and verify the OLT/ONUs are disabled properly
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ENABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=false
        #Verify that ping fails
        Run Keyword If    ${has_dataplane}
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Remove Subscriber Access (To replicate ATT workflow)
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
    END
    #Enable the OLT back and check ONU, OLT status are back to "ACTIVE"
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Port Types
    ...    PON_OLT    ETHERNET_NNI
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test Disable and Enable ONU
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs and validate that the pings do not succeed
    ...    Perform enable on the ONUs and validate that the pings are successful
    [Tags]    functional    DisableEnableONU    released
    [Setup]    Start Logging    DisableEnableONU
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableONU
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
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
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
    [Setup]    Start Logging     SubAddDelete
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SubAddDelete
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
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
    [Setup]    Start Logging    SubsRemoveDHCP
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SubsRemoveDHCP
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
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
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
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
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
    [Setup]    Start Logging    ATT_DisableEnableONU
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ATT_DisableEnableONU
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Disable Device    ${onu_device_id}
        Sleep    30s
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s    Check Ping
        ...    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ELSE    sleep    60s
        Enable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate Authentication After Reassociate    True
        ...    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU in AAA-Users    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Sleep    30s
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Collect Logs
    END

Delete OLT, ReAdd OLT and Perform Sanity Test
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Disable and Delete the OLT
    ...    Create/Enable the same OLT again
    ...    Validate authentication/DHCP/E2E pings succeed for all the ONUs connected to the OLT
    [Tags]    functional    DeleteOLT    released
    [Setup]    Start Logging    DeleteOLT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DeleteOLT
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Delete Device and Verify
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    Run Keyword and Ignore Error    Collect Logs
    # Recreate the OLT
    Setup
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test

Check Mib State on OLT recreation after ONU, OLT deletion
    [Documentation]    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable,
    ...    Disable and Delete the ONU, Disable and Delete the OLT
    ...    Create/Enable the OLT again and Check for the Mib State of the ONUs
    [Tags]    functional    CheckMibState    notready
    [Setup]    Start Logging    CheckMibState
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    CheckMibState
    #Disable and Delete the ONU
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    20s    2s    Test Devices Disabled in VOLTHA    Id=${onu_device_id}
        Delete Device     ${onu_device_id}
    END
    #Disable and Delete the OLT
    Delete Device and Verify
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    # Recreate the OLT
    Run Keyword If    ${has_dataplane}    Sleep    180s
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED
    ...    UNKNOWN    UNKNOWN    ${olt_device_id}
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    #Check for the ONU status and ONU Mib State should be "omci-flows-pushed"
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
    END

Test disable ONUs and OLT then delete ONUs and OLT
    [Documentation]    On deployed POD, disable the ONU, disable the OLT and then delete ONU and OLT.
    ...    This TC is to confirm that ONU removal is not impacting OLT
    ...    Devices will be removed during the execution of this TC
    ...    so calling setup at the end to add the devices back to avoid the confusion.
    [Tags]    functional    VOL-2354    DisableDeleteONUandOLT    released
    [Setup]    Start Logging    DisableDeleteONUandOLT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableDeleteONUandOLT
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
        Delete Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${olt_serial_number}
    END
    Delete Device    ${olt_device_id}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Test Empty Device List
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}

Validate authentication on a disabled ONU
    [Documentation]    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Perform disable on the ONUs and validate that the authentication do not succeed
    ...    Perform enable on the ONUs and validate that authentication successful
    [Tags]    functional    DisableONU_AuthCheck
    # Creates Devices in the Setup
    [Setup]    Run Keywords    Start Logging    DisableONU_AuthCheck
    ...        AND    Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableONU_AuthCheck
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

Data plane verification using TCP
    [Documentation]    Test bandwidth profile is met and not exceeded for each subscriber.
    ...    Assumes iperf3 and jq installed on client and iperf -s running on DHCP server
    [Tags]    dataplane    BandwidthProfileTCP    VOL-2052    notready
    [Setup]    Start Logging    BandwidthProfileTCP
    [Teardown]    Run Keywords    Collect Logs
    ...           AND    Stop Logging    BandwidthProfileTCP
    Pass Execution If   '${has_dataplane}'=='False'    Bandwidth profile validation can be done only in
    ...    physical pod.  Skipping this test in BBSIM.
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}

        # Check for iperf3 and jq tools
        ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf3 jq
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Pass Execution If    ${rc} != 0    Skipping test: iperf3 / jq not found on the RG

        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${subscriber_id}=    Set Variable    ${of_id}/${onu_port}
        ${bandwidth_profile_name}    Get Bandwidth Profile Name For Given Subscriber    ${subscriber_id}
        ...    upstreamBandwidthProfile
        ${limiting_bw_value_upstream}    Get Bandwidth Details    ${bandwidth_profile_name}
        ${bandwidth_profile_name}    Get Bandwidth Profile Name For Given Subscriber    ${subscriber_id}
        ...    downstreamBandwidthProfile
        ${limiting_bw_value_dnstream}    Get Bandwidth Details    ${bandwidth_profile_name}

        # Stream TCP packets from RG to server
        ${updict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
        ...    args=-t 30
        ${actual_upstream_bw_used}=    Evaluate    ${updict['end']['sum_received']['bits_per_second']}/1000

        # Stream TCP packets from server to RG
        ${dndict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
        ...    args=-R -t 30
        ${actual_dnstream_bw_used}=    Evaluate    ${dndict['end']['sum_received']['bits_per_second']}/1000

        ${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${limiting_bw_value_upstream}
        ${pct_limit_dn}=    Evaluate    100*${actual_dnstream_bw_used}/${limiting_bw_value_dnstream}
        Log    Up: bwprof ${limiting_bw_value_upstream}Kbps, got ${actual_upstream_bw_used}Kbps (${pct_limit_up}%)
        Log    Down: bwprof ${limiting_bw_value_dnstream}Kbps, got ${actual_dnstream_bw_used}Kbps (${pct_limit_dn}%)

        Should Be True    ${pct_limit_up} <= ${upper_margin_pct}
        ...    The upstream bandwidth exceeded the limit (${pct_limit_up}% of limit)
        Should Be True    ${pct_limit_dn} <= ${upper_margin_pct}
        ...    The downstream bandwidth exceeded the limit (${pct_limit_dn}% of limit)
        Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
        ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)
        Should Be True    ${pct_limit_dn} >= ${lower_margin_pct}
        ...    The downstream bandwidth guarantee was not met (${pct_limit_dn}% of resv)
    END

Data plane verification using UDP
    [Documentation]    Test bandwidth profile is met and not exceeded for each subscriber.
    ...    Assumes iperf3 and jq installed on client and iperf -s running on DHCP server
    [Tags]    dataplane    BandwidthProfileUDP    VOL-2052    notready
    [Setup]    Start Logging    BandwidthProfileUDP
    [Teardown]    Run Keywords    Collect Logs
    ...           AND    Stop Logging    BandwidthProfileUDP
    Pass Execution If   '${has_dataplane}'=='False'    Bandwidth profile validation can be done only in
    ...    physical pod.  Skipping this test in BBSIM.
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${subscriber_id}=    Set Variable    ${of_id}/${onu_port}
        ${bandwidth_profile_name}    Get Bandwidth Profile Name For Given Subscriber    ${subscriber_id}
        ...    upstreamBandwidthProfile
        ${limiting_bw_value_upstream}    Get Bandwidth Details    ${bandwidth_profile_name}
        ${bandwidth_profile_name}    Get Bandwidth Profile Name For Given Subscriber    ${subscriber_id}
        ...    downstreamBandwidthProfile
        ${limiting_bw_value_dnstream}    Get Bandwidth Details    ${bandwidth_profile_name}

        # Stream UDP packets from RG to server
        ${uprate}=    Evaluate    ${limiting_bw_value_upstream}*${udp_rate_multiplier}
        ${updict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
        ...    args=-u -b ${uprate}K -t 30 -l ${udp_packet_bytes}
        # With UDP test, bits per second is the sending rate.  Multiply by the loss rate to get the throughput.
        ${actual_upstream_bw_used}=    Evaluate
        ...    (100 - ${updict['end']['sum']['lost_percent']})*${updict['end']['sum']['bits_per_second']}/100000

        # Stream UDP packets from server to RG
        ${dnrate}=    Evaluate    ${limiting_bw_value_dnstream}*${udp_rate_multiplier}
        ${dndict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
        ...    args=-u -b ${dnrate}K -R -t 30 -l ${udp_packet_bytes}
        # With UDP test, bits per second is the sending rate.  Multiply by the loss rate to get the throughput.
        ${actual_dnstream_bw_used}=    Evaluate
        ...    (100 - ${dndict['end']['sum']['lost_percent']})*${dndict['end']['sum']['bits_per_second']}/100000

        ${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${limiting_bw_value_upstream}
        ${pct_limit_dn}=    Evaluate    100*${actual_dnstream_bw_used}/${limiting_bw_value_dnstream}
        Log    Up: bwprof ${limiting_bw_value_upstream}Kbps, got ${actual_upstream_bw_used}Kbps (${pct_limit_up}%)
        Log    Down: bwprof ${limiting_bw_value_dnstream}Kbps, got ${actual_dnstream_bw_used}Kbps (${pct_limit_dn}%)

        Should Be True    ${pct_limit_up} <= ${upper_margin_pct}
        ...    The upstream bandwidth exceeded the limit (${pct_limit_up}% of limit)
        Should Be True    ${pct_limit_dn} <= ${upper_margin_pct}
        ...    The downstream bandwidth exceeded the limit (${pct_limit_dn}% of limit)
        Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
        ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)
        Should Be True    ${pct_limit_dn} >= ${lower_margin_pct}
        ...    The downstream bandwidth guarantee was not met (${pct_limit_dn}% of resv)
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
