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
${teardown_device}    True
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful DHCP/E2E ping (no EAPOL and DHCP flows) for the tech profile that is used
    ...    Traffic sent with same vlan from different RGs,
    ...    should reach the NNI port on the OLT with the expected double tagged vlan ids
    ...    Inner vlans from the RG should not change
    [Tags]    sanityDt
    [Setup]    Run Keywords    Start Logging    SanityTestDt
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTestDt
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT

Test Subscriber Delete and Add for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Delete a subscriber and validate that the pings do not succeed and state is purged
    ...    Disable and Enable the ONU (This is to replicate the existing DT behaviour)
    ...    Re-add the subscriber, and validate that the flows are present and pings are successful
    [Tags]    functionalDt    SubAddDeleteDt
    [Setup]    Start Logging     SubAddDeleteDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SubAddDeleteDt
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        # Remove Subscriber Access
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Number of Access Flows on ONOS equals 4 * the Number of Active ONUs (2 for each downstream and upstream)
        ${onos_flows_count}=    Evaluate    4 * ( ${num_onus} - 1 )
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added Count DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${of_id}    ${onos_flows_count}
        # Verify VOLTHA flows for OLT equals twice the number of ONUS (minus ONU under test) + 1 for LLDP
        ${olt_flows}=    Evaluate    2 * ( ${num_onus} - 1 ) + 1
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows    ${olt_flows}
        # Verify VOLTHA flows for ONU under test is Zero
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Flows
        ...    ${onu_device_id}    0
        # Disable and Re-Enable the ONU (To replicate DT current workflow)
        # TODO: Delete and Auto-Discovery Add of ONU (not yet supported)
        Disable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}
        Enable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}
        # Add Subscriber Access
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
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

Test Disable and Enable ONU for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the ONUs and validate that the pings do not succeed
    ...    Perform enable on the ONUs and validate that the pings are successful
    [Tags]    functionalDt    DisableEnableONUDt
    [Setup]    Start Logging    DisableEnableONUDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableONUDt
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Disable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-admin-lock
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Sleep    5s
        Enable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=onu-reenabled
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

Test Disable and Delete OLT for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the OLT and validate ONUs state and that the pings do not succeed
    ...    Perform delete on the OLT, Re-do Setup (Recreate the OLT) and Perform Sanity Test DT
    [Tags]    functionalDt    DisableDeleteOLTDt
    [Setup]    Start Logging    DisableDeleteOLTDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableDeleteOLTDt
    # Disable and Validate OLT Device
    Disable Device    ${olt_device_id}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    # Validate ONUs
    Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONUs After OLT Disable
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
    # Delete OLT and Validate Empty Device List
    Delete Device    ${olt_device_id}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Test Empty Device List
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    Run Keyword and Ignore Error    Collect Logs
    # Re-do Setup (Recreate the OLT) and Perform Sanity Test DT
    Run Keyword    Setup
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test DT
    Run Keyword If    ${has_dataplane}    Clean Up Linux

Test Disable and Enable OLT for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the OLT and validate that the pings do not succeed
    ...    Perform enable on the OLT and validate that the pings are successful
    [Tags]    functionalDt    DisableEnableOLTDt    notready
    [Setup]    Start Logging    DisableEnableOLTDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableOLTDt
    # Disable and Validate OLT Device
    Disable Device    ${olt_device_id}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Remove Subscriber Access (To replicate DT workflow)
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        # Delete ONU Device (To replicate DT workflow)
        Delete Device    ${onu_device_id}
    END
    Sleep    15s
    # Enable the OLT back and check ONU, OLT status are back to "ACTIVE"
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Port Types
    ...    PON_OLT    ETHERNET_NNI
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test DT

Test Delete and ReAdd OLT for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Disable and Delete the OLT
    ...    Create/Enable the same OLT again
    ...    Validate DHCP/E2E pings succeed for all the ONUs connected to the OLT
    [Tags]    functionalDt    DeleteReAddOLTDt
    [Setup]    Start Logging    DeleteReAddOLTDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DeleteReAddOLTDt
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Delete Device and Verify
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    Run Keyword and Ignore Error    Collect Logs
    # Recreate the OLT
    Setup
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test DT

Test Disable ONUs and OLT Then Delete ONUs and OLT for DT
    [Documentation]    On deployed POD, disable the ONU, disable the OLT and then delete ONU and OLT.
    ...    This TC is to confirm that ONU removal is not impacting OLT
    ...    Devices will be removed during the execution of this TC
    ...    so calling setup at the end to add the devices back to avoid the confusion.
    [Tags]    functionalDt    DisableDeleteONUOLTDt
    [Setup]    Start Logging    DisableDeleteONUOLTDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableDeleteONUOLTDt
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
        Disable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=false
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
    END
    Disable Device    ${olt_device_id}
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
    # Re-do Setup (Recreate the OLT) and Perform Sanity Test DT
    Run Keyword    Setup
    Wait Until Keyword Succeeds    ${timeout}   2s    Perform Sanity Test DT
    Run Keyword If    ${has_dataplane}    Clean Up Linux

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

