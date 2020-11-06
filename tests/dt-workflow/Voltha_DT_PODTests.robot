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
${timeout}        360s
${of_id}          0
${logical_id}     0
${uprate}         0
${dnrate}         0
${has_dataplane}    True
${teardown_device}    True
${scripts}        ../../scripts

# For dataplane bandwidth testing
${upper_margin_pct}      105     # Allow 5% over the limit
${lower_margin_pct}      90      # Allow 8% under the limit
${udp_rate_multiplier}   1.10    # Send UDP at bw profile limit * rate_multiplier
${udp_packet_bytes}      1470    # UDP payload in bytes

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Reboot DT ONUs Physically
    [Documentation]   This test reboots ONUs physically before execution all the tests
    ...    Test case runs only on the PODs that are configured with PowerSwitch that
    ...    controls the power off/on ONUs/OLT remotely (simulating a physical reboot)
    [Tags]    functionalDt   PowerSwitch    RebootAllDTONUs
    [Setup]    Start Logging    RebootAllDTONUs
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RebootAllDTONUs
    Power Switch Connection Suite    ${web_power_switch.ip}    ${web_power_switch.user}    ${web_power_switch.password}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Disable Switch Outlet    ${src['power_switch_port']}
        Sleep    60s
        Enable Switch Outlet    ${src['power_switch_port']}
        Sleep    60s
    END

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
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
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
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
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
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Sleep    5s
        Enable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=onu-reenabled
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
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
    [Tags]    functionalDt    DisableEnableOLTDt
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
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Remove Subscriber Access (To replicate DT workflow)
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        Sleep    10s
        # Delete ONU Device (To replicate DT workflow)
        Delete Device    ${onu_device_id}
        Sleep    5s
    END
    Sleep    5s
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    # Enable the OLT back and check ONU, OLT status are back to "ACTIVE"
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Port Types
    ...    PON_OLT    ETHERNET_NNI
    # Waiting extra time for the ONUs to come up
    Sleep    60s
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

Data plane verification using TCP for DT
    [Documentation]    Test bandwidth profile is met and not exceeded for each subscriber.
    ...    Assumes iperf3 and jq installed on client and iperf -s running on DHCP server
    [Tags]    dataplaneDt    BandwidthProfileTCPDt    VOL-3061
    [Setup]    Start Logging    BandwidthProfileTCPDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND    Stop Logging    BandwidthProfileTCPDt
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
        # VOL-3125: downstream bw limit not enforced.  Uncomment when fixed.
        #Should Be True    ${pct_limit_dn} <= ${upper_margin_pct}
        #...    The downstream bandwidth exceeded the limit (${pct_limit_dn}% of limit)
        Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
        ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)
        Should Be True    ${pct_limit_dn} >= ${lower_margin_pct}
        ...    The downstream bandwidth guarantee was not met (${pct_limit_dn}% of resv)
    END

Data plane verification using UDP for DT
    [Documentation]    Test bandwidth profile is met and not exceeded for each subscriber.
    ...    Assumes iperf3 and jq installed on client and iperf -s running on DHCP server
    [Tags]    dataplaneDt    BandwidthProfileUDPDt    VOL-3061
    [Setup]    Start Logging    BandwidthProfileUDPDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND    Stop Logging    BandwidthProfileUDPDt
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

        # Stream UDP packets from RG to server
        ${uprate}=    Run Keyword If    ${limiting_bw_value_upstream} != 1000000
        ...    Evaluate    ${limiting_bw_value_upstream}*${udp_rate_multiplier}
        ...    ELSE
        ...    Set Variable  ${limiting_bw_value_upstream}

        ${updict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
        ...    args=-u -b ${uprate}K -t 30 -l ${udp_packet_bytes} --pacing-timer 0
        # With UDP test, bits per second is the sending rate.  Multiply by the loss rate to get the throughput.
        ${actual_upstream_bw_used}=    Evaluate
        ...    (100 - ${updict['end']['sum']['lost_percent']})*${updict['end']['sum']['bits_per_second']}/100000

        # Stream UDP packets from server to RG
        ${dnrate}=    Run Keyword If    ${limiting_bw_value_dnstream} != 1000000
        ...    Evaluate    ${limiting_bw_value_dnstream}*${udp_rate_multiplier}
        ...    ELSE
        ...    Set Variable  ${limiting_bw_value_dnstream}
        ${dndict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
        ...    args=-u -b ${dnrate}K -R -t 30 -l ${udp_packet_bytes} --pacing-timer 0
        # With UDP test, bits per second is the sending rate.  Multiply by the loss rate to get the throughput.
        ${actual_dnstream_bw_used}=    Evaluate
        ...    (100 - ${dndict['end']['sum']['lost_percent']})*${dndict['end']['sum']['bits_per_second']}/100000

        ${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${limiting_bw_value_upstream}
        ${pct_limit_dn}=    Evaluate    100*${actual_dnstream_bw_used}/${limiting_bw_value_dnstream}
        Log    Up: bwprof ${limiting_bw_value_upstream}Kbps, got ${actual_upstream_bw_used}Kbps (${pct_limit_up}%)
        Log    Down: bwprof ${limiting_bw_value_dnstream}Kbps, got ${actual_dnstream_bw_used}Kbps (${pct_limit_dn}%)

        Should Be True    ${pct_limit_up} <= ${upper_margin_pct}
        ...    The upstream bandwidth exceeded the limit (${pct_limit_up}% of limit)
        # VOL-3125: downstream bw limit not enforced.  Uncomment when fixed.
        #Should Be True    ${pct_limit_dn} <= ${upper_margin_pct}
        #...    The downstream bandwidth exceeded the limit (${pct_limit_dn}% of limit)
        Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
        ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)
        Should Be True    ${pct_limit_dn} >= ${lower_margin_pct}
        ...    The downstream bandwidth guarantee was not met (${pct_limit_dn}% of resv)
    END

Validate parsing of data traffic through voltha using tech profile
    [Documentation]    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Prerequisite tools : Tcpdump and Mausezahn traffic generator on both RG and DHCP/BNG VMs
    ...    Install jq tool to read json file, where test suite is being running
    ...    Make sure 9999 port is enabled or forwarded for both upsteam and downstream direction
    ...    This test sends UDP packets on port 9999 with pbits between 0 and 7 and validates that
    ...    the pbits are preserved by the PON.
    [Tags]    dataplaneDt    TechProfileDt    VOL-3291
    [Setup]    Start Logging    TechProfileDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND    Stop Logging    TechProfileDt
    Pass Execution If   '${has_dataplane}'=='False'
    ...    Skipping test: Technology profile validation can be done only in physical pod
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}

        ${src_iface_name}=    Fetch From Left    ${src['dp_iface_name']}    .

        ${bng_ip}=    Get Variable Value    ${dst['noroot_ip']}
        ${bng_user}=    Get Variable Value    ${dst['noroot_user']}
        ${bng_pass}=    Get Variable Value    ${dst['noroot_pass']}
        Pass Execution If    "${bng_ip}" == "${NONE}" or "${bng_user}" == "${NONE}" or "${bng_pass}" == "${NONE}"
        ...    Skipping test: credentials for BNG login required in deployment config

        ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which mausezahn tcpdump
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Pass Execution If    ${rc} != 0    Skipping test: mausezahn / tcpdump not found on the RG
        ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which mausezahn tcpdump
        ...    ${bng_ip}    ${bng_user}    ${bng_pass}    ${dst['container_type']}    ${dst['container_name']}
        Pass Execution If    ${rc} != 0    Skipping test: mausezahn / tcpdump not found on the BNG
        Log    Upstream test
        Run Keyword If    ${has_dataplane}    Create traffic with each pbit and capture at other end
        ...    ${dst['dp_iface_ip_qinq']}    ${dst['dp_iface_name']}    ${src_iface_name}
        ...    0    udp    9999    ${src['c_tag']}    vlan
        ...    ${bng_ip}    ${bng_user}    ${bng_pass}    ${dst['container_type']}    ${dst['container_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Log    Downstream test
        ${rg_ip}    ${stderr}    ${rc}=    Execute Remote Command
        ...    ifconfig ${src['dp_iface_name']} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Should Be Equal As Integers    ${rc}    0    Could not get RG's IP address
        Run Keyword If    ${has_dataplane}    Create traffic with each pbit and capture at other end
        ...    ${rg_ip}    ${src_iface_name}    ${dst['dp_iface_name']}.${src['s_tag']}
        ...    0    udp    9999    ${src['c_tag']}    udp
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${bng_ip}    ${bng_user}    ${bng_pass}    ${dst['container_type']}    ${dst['container_name']}
    END

Test Disable and Enable OLT PON Port for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the OLT PON Port and validate that the pings do not succeed
    ...    Perform enable on the OLT PON Port and validate that the pings are successful
    [Tags]    functionalDt    DisableEnableOltPonPortDt    VOL-2577
    [Setup]    Start Logging    DisableEnableOltPonPortDt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableOltPonPortDt
    ${olt_pon_port_list}=    Retrieve OLT PON Ports    ${olt_device_id}
    ${olt_pon_port_list_len}=    Get Length    ${olt_pon_port_list}
    FOR    ${INDEX0}    IN RANGE    0    ${olt_pon_port_list_len}
        ${olt_pon_port}=    Get From List    ${olt_pon_port_list}    ${INDEX0}
        ${olt_peer_list}=    Retrieve Peer List From OLT PON Port    ${olt_device_id}    ${olt_pon_port}
        # Disable the OLT PON Port and Validate OLT Device
        DisableOrEnable OLT PON Port    disable    ${olt_device_id}    ${olt_pon_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT PON Port Status    ${olt_device_id}    ${olt_pon_port}
        ...    DISABLED    DISCOVERED
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate ONUs for PON OLT Disable DT    ${olt_peer_list}
        Sleep    15s
        # Enable the OLT PON Port back, and check ONU status are back to "ACTIVE"
        DisableOrEnable OLT PON Port    enable    ${olt_device_id}    ${olt_pon_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT PON Port Status    ${olt_device_id}    ${olt_pon_port}
        ...    ENABLED    ACTIVE
        # Waiting extra time for the ONUs to come up
        Sleep    60s
        ${olt_peer_list_new}=    Retrieve Peer List From OLT PON Port    ${olt_device_id}    ${olt_pon_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate ONUs for PON OLT Enable DT    ${olt_peer_list_new}
    END

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #Restore all ONUs
    #Run Keyword If    ${has_dataplane}    RestoreONUs    ${num_onus}
    #power_switch.robot needs it to support different vendor's power switch
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup

