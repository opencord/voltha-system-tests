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
Resource          ../../libraries/onu_utilities.robot

*** Variables ***
${POD_NAME}       flex-ocp-cord
${KUBERNETES_CONF}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}    ~/pod-configs/kubernetes-configs
#${KUBERNETES_CONFIGS_DIR}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${NAMESPACE}      voltha
${INFRA_NAMESPACE}      default
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    True
${scripts}        ../../scripts
${data_dir}    ../data
# flag to reboot OLT through Power Switch
${power_cycle_olt}    False

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

${suppressaddsubscriber}    True

# flag to choose if mac-learning is enabled, or disabled (i.e. mac-address is configured)
# example: -v with_maclearning:True
${with_maclearning}    False

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

*** Test Cases ***
Reboot TT ONUs and OLTs Physically - Clean Up
    [Documentation]   This test reboots ONUs and OLTs physically before execution all the tests
    ...    Test case runs only on the PODs that are configured with PowerSwitch that
    ...    controls the power off/on ONUs/OLT remotely (simulating a physical reboot)
    [Tags]    functionalTT   PowerSwitch    RebootAllTTONUsOLTs
    [Setup]    Start Logging    RebootAllTTONUsOLTs
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RebootAllTTONUsOLTs
    Perform Reboot ONUs and OLTs Physically    ${power_cycle_olt}

Sanity E2E Test for TT (HSIA, VoD, VoIP)
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful DHCP/E2E ping (no EAPOL and DHCP flows) for the tech profile that is used
    ...    Traffic sent with same vlan from different RGs,
    ...    should reach the NNI port on the OLT with the expected double tagged vlan ids
    ...    Inner vlans from the RG should not change
    [Tags]    sanityTT
    [Setup]    Run Keywords    Start Logging    SanityTestTT
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTestTT
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test TT    maclearning_enabled=${with_maclearning}

Sanity E2E Test for TT (MCAST)
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful DHCP/E2E ping (no EAPOL and DHCP flows) for the tech profile that is used
    ...    Traffic sent with same vlan from different RGs,
    ...    should reach the NNI port on the OLT with the expected double tagged vlan ids
    ...    Inner vlans from the RG should not change
    [Tags]    sanityTT-MCAST
    [Setup]    Run Keyword    Start Logging    SanityTestTT-MCAST
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTestTT-MCAST
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test TT MCAST

Test Disable and Delete OLT for TT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityTt test was executed)
    ...    Perform disable on the OLT and validate ONUs state and that the pings do not succeed
    ...    Perform delete on the OLT, Re-do Setup (Recreate the OLT) and Perform Sanity Test TT
    [Tags]    functionalTT    DisableDeleteOLTTt
    [Setup]    Start Logging    DisableDeleteOLTTt
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableDeleteOLTTt
    @{particular_onu_device_port}=      Create List
    FOR   ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        Append To List  ${particular_onu_device_port}    ${onu_port}
    END
    ${list_onu_port}=    Remove Duplicates    ${particular_onu_device_port}
    ${num_of_provisioned_onus}=    Get Length  ${list_onu_port}
    # Disable and Validate OLT Device
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Disable Device    ${olt_device_id}
        ${of_id}=    Get ofID From OLT List    ${olt_serial_number}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
        ...    ${olt_serial_number}
        ${num_onus}=    Set Variable    ${list_olts}[${I}][onucount]
        # Validate ONUs
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONUs After OLT Disable
        ...    ${num_onus}    ${olt_serial_number}
        # Verify ONOS Flows
        # Number of Access Flows on ONOS equals 16 * the Number of Active ONUs + 3 for default LLDP, IGMP and DHCP
        ${onos_flows_count}=    Run Keyword If    ${has_dataplane}    Evaluate    16 * ${num_of_provisioned_onus} + 3
        ...    ELSE    Evaluate    15 * ${num_of_provisioned_onus} + 3
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Added Flow Count for OLT TT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onos_flows_count}
        # Verify VOLTHA Flows
        # Number of per OLT Flows equals 10 * Number of Active ONUs  + 3 for default LLDP, IGMP and DHCP
        ${olt_flows}=    Run Keyword If    ${has_dataplane}    Evaluate    10 * ${num_of_provisioned_onus} + 3
        ...    ELSE    Evaluate    9 * ${num_of_provisioned_onus} + 3
        # Number of per ONU Flows equals 6 for 3play service data plane + 4 for Trap to Host Flows
        ${onu_flows}=    Run Keyword If    ${has_dataplane}    Set Variable    10
        ...    ELSE    Set Variable    9
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows    ${olt_flows}
        ...    ${olt_device_id}
        ${List_ONU_Serial}    Create List
        Set Suite Variable    ${List_ONU_Serial}
        Build ONU SN List    ${List_ONU_Serial}    ${olt_serial_number}    ${num_onus}
        Log    ${List_ONU_Serial}
        # TODO: Fix ${onu_flows} calculations based on UNIs provisioned
        # Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONU Flows
        # ...    ${List_ONU_Serial}    ${onu_flows}
        # Delete OLT and Validate Empty Device List
        Delete Device    ${olt_device_id}
        # Check that the OLT and the ONUs are actually removed from the system
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed
        ...    ${olt_serial_number}
        Run Keyword and Continue On Failure    Validate all ONUS for OLT Removed    ${num_all_onus}    ${hosts}
        ...    ${olt_serial_number}    ${timeout}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    END
    # Re-do Setup (Recreate the OLT) and Perform Sanity Test TT
    Run Keyword    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Tests TT

Verify re-provisioning subscriber after removing provisoned subscriber for TT
    [Documentation]    Removing/Readding a particular subscriber should have no effect on any other subscriber.
    [Tags]    functionalTT    Readd-subscriber-TT
    [Setup]    Start Logging    Readd-subscriber-TT
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    Readd-subscriber-TT
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR   ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${service_type}=    Get Variable Value    ${src['service_type']}    "null"
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Remove Subscriber Access
        ${del_sub_cmd}=    Run Keyword If    ${unitag_sub}
        ...    Catenate    volt-remove-subscriber-unitag --tpId ${src['tp_id']} --sTag ${src['s_tag']}
        ...    --cTag ${src['c_tag']} ${src['onu']}-${src['uni_id']}
        ...    ELSE
        ...    Set Variable    volt-remove-subscriber-access ${of_id} ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${del_sub_cmd}
        Run Keyword If    ${has_dataplane} and '${service_type}' != 'mcast'
        ...    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ELSE    Sleep    10s    Wait for flows to be deleted
        Run Keyword If    ${unitag_sub} and '${service_type}' != 'mcast'
        ...    Wait Until Keyword Succeeds    ${timeout}    2s    Verify UniTag Subscriber    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${of_id}    ${onu_port}    ${src['s_tag']}    ${src['c_tag']}    ${src['tp_id']}    False
        # Verify VOLTHA flows for ONU under test is Zero
        # TODO: Fix ${onu_flows} calculations based on UNIs provisioned
        # Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Flows
        # ...    ${onu_device_id}    0
        # Add Subscriber Access
        ${add_sub_cmd}=    Run Keyword If    ${unitag_sub}
        ...    Catenate    volt-add-subscriber-unitag --tpId ${src['tp_id']} --sTag ${src['s_tag']}
        ...    --cTag ${src['c_tag']} ${src['onu']}-${src['uni_id']}
        ...    ELSE
        ...    Set Variable    volt-add-subscriber-access ${of_id} ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    ${add_sub_cmd}
        Run Keyword If    ${unitag_sub} and '${service_type}' != 'mcast'
        ...    Wait Until Keyword Succeeds    ${timeout}    2s    Verify UniTag Subscriber    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${of_id}    ${onu_port}    ${src['s_tag']}    ${src['c_tag']}    ${src['tp_id']}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        Run Keyword If    ${has_dataplane} and '${service_type}' != 'mcast'
        ...    Sanity Test TT one ONU    ${src}    ${dst}    ${suppressaddsubscriber}
        ...    ELSE IF    ${has_dataplane} and '${service_type}' == 'mcast'
        ...    Sanity Test TT MCAST one ONU    ${src}    ${dst}    ${suppressaddsubscriber}
    END

Test Disable and Enable ONU for TT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanitytt test was executed)
    ...    Perform disable on the ONUs and validate that the pings do not succeed
    ...    Perform enable on the ONUs and validate that the pings are successful
    [Tags]    functionalTT    DisableEnableONUTT
    [Setup]    Run Keywords    Start Logging    DisableEnableONUTT
    ...        AND    Run Keyword If    ${has_dataplane}    Set Non-Critical Tag for XGSPON Tech
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableEnableONUTT
    @{onu_list}=    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${sn}=     Set Variable    ${src['onu']}
        # make sure all actions do only once per onu
        ${onu_id}=    Get Index From List    ${onu_list}   ${sn}
        Continue For Loop If    -1 != ${onu_id}
        Append To List    ${onu_list}    ${sn}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Get Onu Ports in ONOS For ALL UNI per ONU    ${src['onu']}    ${of_id}
        Log    ${onu_port}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Disable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-admin-lock
        Wait For All UNI Ports Are Disabled per ONU   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Sleep    5s
        Enable Device    ${onu_device_id}
        Wait For All UNI Ports Are Enabled per ONU   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        # Workaround for issue seen in VOL-4489. Keep this workaround until VOL-4489 is fixed.
        Run Keyword If    ${has_dataplane}    Reboot XGSPON ONU    ${src['olt']}    ${src['onu']}    omci-flows-pushed
        # Workaround ends here for issue seen in VOL-4489.
        Run Keyword If    ${has_dataplane}    Clean Up Linux
        Run Keyword If    ${has_dataplane}    Wait For All UNI Ports Are Enabled per ONU   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${src['onu']
        Perform Sanity Tests TT    ${suppressaddsubscriber}
    END

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    # pre-load tech profiles to use single instance control for HSIA and VoIP, multi instance control for MCAST
    Run Keyword If    ${unitag_sub} and not ${has_dataplane}   Set Tech Profile    TT-HSIA    ${INFRA_NAMESPACE}    64
    Run Keyword If    ${unitag_sub} and not ${has_dataplane}    Set Tech Profile    TT-VoIP    ${INFRA_NAMESPACE}    65
    Run Keyword If    ${unitag_sub} and not ${has_dataplane}    Set Tech Profile    TT-multi-uni-MCAST-AdditionalBW-None
    ...    ${INFRA_NAMESPACE}    66
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}


Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup


Teardown Suite
    [Documentation]    Tear down steps for the suite
    Start Logging Setup or Teardown  Teardown-${SUITE NAME}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${teardown_device}    Delete All Devices And Verify    maclearning_enabled=${with_maclearning}
    Close All ONOS SSH Connections
    # remove pre-loaded tech profiles
    Set Suite Variable    ${TechProfile}    ${EMPTY}
    Run Keyword If    ${unitag_sub} and not ${has_dataplane}    Remove Tech Profile    ${INFRA_NAMESPACE}    64
    Run Keyword If    ${unitag_sub} and not ${has_dataplane}    Remove Tech Profile    ${INFRA_NAMESPACE}    65
    Run Keyword If    ${unitag_sub} and not ${has_dataplane}    Remove Tech Profile    ${INFRA_NAMESPACE}    66
    Stop Logging Setup or Teardown    Teardown-${SUITE NAME}
