# Copyright 2017-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
Suite Teardown    Setup Teardown
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
${POD_NAME}       bbsim-kind-dt
${KUBERNETES_CONF}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}    ~/pod-configs/kubernetes-configs
#${KUBERNETES_CONFIGS_DIR}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
#${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${KUBERNETES_YAML}    /test/repos/voltha-system-tests/tests/data/bbsim-kind-dt-vgc.yaml
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
${uprate}         0
${dnrate}         0
${has_dataplane}    True
${teardown_device}    True
${scripts}        ../../scripts
# flag to reboot OLT through Power Switch
${power_cycle_olt}    False

# For dataplane bandwidth testing
${upper_margin_pct}      105     # Allow 5% over the limit
${lower_margin_pct}      90      # Allow 8% under the limit
${udp_rate_multiplier}   1.10    # Send UDP at bw profile limit * rate_multiplier
${udp_packet_bytes}      1470    # UDP payload in bytes

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

# Flag specific to Soak Jobs
${SOAK_TEST}    False
${bbsim_port}    50060

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful DHCP/E2E ping (no EAPOL and DHCP flows) for the tech profile that is used
    ...    Traffic sent with same vlan from different RGs,
    ...    should reach the NNI port on the OLT with the expected double tagged vlan ids
    ...    Inner vlans from the RG should not change
    [Tags]    sanityDt   soak
    [Setup]    Run Keywords    Start Logging    SanityTestDt
    ...        AND    Verify Ofagent Pod Availablity
#    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
#    ...           AND             Stop Logging    SanityTestDt
    Setup    ${SOAK_TEST}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT

Test Subscriber Delete and Add for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Delete a subscriber and validate that the pings do not succeed and state is purged
    ...    Disable and Enable the ONU (This is to replicate the existing DT behaviour)
    ...    Re-add the subscriber, and validate that the flows are present and pings are successful
    [Tags]    functionalDt    SubAddDeleteDt    soak
    [Setup]    Run Keywords    Start Logging     SubAddDeleteDt
    ...        AND    Run Keyword If    ${has_dataplane}    Set Non-Critical Tag for XGSPON Tech
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    SubAddDeleteDt
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${src['olt']}
        ${num_of_olt_onus}=    Get Num of Onus From OLT SN    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in VGC    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        # Remove Subscriber Access
	    Delete Request    VGC    services/${of_id}/${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}

        # Number of Access Flows on VGC equals 4 * the Number of Active ONUs (2 for each downstream and upstream)
        ${vgc_flows_count}=    Evaluate    4 * ( ${num_of_olt_onus} - 1 )
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added Count DT    ${VGC_SSH_IP}    ${VGC_SSH_PORT}
        ...    ${of_id}    ${vgc_flows_count}
        # Verify VOLTHA flows for OLT equals twice the number of ONUS (minus ONU under test) + 1 for LLDP
        ${olt_flows}=    Evaluate    2 * ( ${num_of_olt_onus} - 1 )
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows
        ...    ${olt_flows}    ${olt_device_id}
        # Verify VOLTHA flows for ONU under test is Zero
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Flows
        ...    ${onu_device_id}    0
        # Disable and Re-Enable the ONU (To replicate DT current workflow)
        # TODO: Delete and Auto-Discovery Add of ONU (not yet supported)
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}
        Enable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    360s    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}
        # Add Subscriber Access
	Post Request    VGC    services/${of_id}/${onu_port}
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
    # Verify flows for all OLTs
    Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate All OLT Flows

Test Disable and Enable ONU for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the ONUs and validate that the pings do not succeed
    ...    Perform enable on the ONUs and validate that the pings are successful
    [Tags]    functionalDt    DisableEnableONUDt    soak
    [Setup]    Run Keywords    Start Logging    DisableEnableONUDt
    ...        AND    Run Keyword If    ${has_dataplane}    Set Non-Critical Tag for XGSPON Tech
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DisableEnableONUDt
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in VGC    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Disable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=omci-admin-lock
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Disabled   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Sleep    5s
        Enable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=onu-reenabled
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Enabled    ${src['onu']}    ${src['uni_id']}
        # Workaround for issue seen in VOL-4489. Keep this workaround until VOL-4489 is fixed.
        Run Keyword If    ${has_dataplane}    Reboot XGSPON ONU    ${src['olt']}    ${src['onu']}    omci-flows-pushed
        # Workaround ends here for issue seen in VOL-4489.
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

Test Disable and Delete OLT for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the OLT and validate ONUs state and that the pings do not succeed
    ...    Perform delete on the OLT, Re-do Setup (Recreate the OLT) and Perform Sanity Test DT
    [Tags]    functionalDt    DisableDeleteOLTDt    soak
    [Setup]    Start Logging    DisableDeleteOLTDt
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DisableDeleteOLTDt
    # Disable and Validate OLT Device
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Disable Device    ${olt_device_id}
        ${of_id}=    Get ofID From OLT List    ${olt_serial_number}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
        ...    ${olt_serial_number}
        ${num_onus}=    Set Variable    ${list_olts}[${I}][onucount]
        # Validate ONUs
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONUs After OLT Disable
        ...    ${num_onus}    ${olt_serial_number}
        # Verify VGC Flows
        # Number of Access Flows on VGC equals 4 * the Number of Active ONUs (2 for each downstream and upstream)
        ${vgc_flows_count}=    Evaluate    4 * ${num_onus}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added Count DT    ${VGC_SSH_IP}    ${VGC_SSH_PORT}
        ...    ${of_id}    ${vgc_flows_count}
        # Verify VOLTHA Flows
        # Number of per OLT Flows equals Twice the Number of Active ONUs (each for downstream and upstream) + 1 for LLDP
        ${olt_flows}=    Evaluate    2 * ${num_onus}
        # Number of per ONU Flows equals 2 (one each for downstream and upstream)
        ${onu_flows}=    Set Variable    2
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows
        ...    ${olt_flows}    ${olt_device_id}
        ${List_ONU_Serial}    Create List
        Set Suite Variable    ${List_ONU_Serial}
        Build ONU SN List    ${List_ONU_Serial}    ${olt_serial_number}    ${num_onus}
        Log    ${List_ONU_Serial}
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONU Flows
        ...    ${List_ONU_Serial}    ${onu_flows}
        # Delete OLT and Validate Empty Device List
        Delete Device    ${olt_device_id}
        # Check that the OLT and the ONUs are actually removed from the system
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed
        ...    ${olt_serial_number}
        Run Keyword and Continue On Failure    Validate all ONUS for OLT Removed    ${num_all_onus}    ${hosts}
        ...    ${olt_serial_number}    ${timeout}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Device Flows Removed    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
    END
    # Re-do Setup (Recreate the OLT) and Perform Sanity Test DT
    Run Keyword    Setup    ${SOAK_TEST}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT

Test Disable and Enable OLT for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the OLT and validate that the pings do not succeed
    ...    Perform enable on the OLT and validate that the pings are successful
    [Tags]    functionalDt    DisableEnableOLTDt   soak
    [Setup]    Start Logging    DisableEnableOLTDt
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DisableEnableOLTDt
    # Disable and Validate OLT Device
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    voltctl -c ${VOLTCTL_CONFIG} device disable ${olt_device_id}
        Should Be Equal As Integers    ${rc}    0
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
        ...    ${olt_serial_number}
    END
    # Validate ONUs
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Disabled   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Remove Subscriber Access (To replicate DT workflow)
        ${onu_port_name}=    Catenate    SEPARATOR=-    ${src['onu']}    ${src['uni_id']}
	Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Delete Request    VGC    services/${onu_port_name}
        # Delete ONU Device (To replicate DT workflow)
        Delete Device    ${onu_device_id}
    END
    Sleep    5s
    # Enable the OLT back and check ONU, OLT status are back to "ACTIVE"
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        #TODO: Update for PON_OLT ETHERNET_NNI
        #Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Port Types
        #...    PON_OLT    ETHERNET_NNI
    END
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT

Test Delete and ReAdd OLT for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Disable and Delete the OLT
    ...    Create/Enable the same OLT again
    ...    Validate DHCP/E2E pings succeed for all the ONUs connected to the OLT
    [Tags]    functionalDt    DeleteReAddOLTDt    soak
    [Setup]    Start Logging    DeleteReAddOLTDt
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DeleteReAddOLTDt
    FOR    ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${of_id}=    Get ofID From OLT List    ${olt_serial_number}
        Delete Device and Verify    ${olt_serial_number}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Device Flows Removed    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
    END
    # Recreate the OLTs
    Setup    ${SOAK_TEST}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT

Test Disable ONUs and OLT Then Delete ONUs and OLT for DT
    [Documentation]    On deployed POD, disable the ONU, disable the OLT and then delete ONU and OLT.
    ...    This TC is to confirm that ONU removal is not impacting OLT
    ...    Devices will be removed during the execution of this TC
    ...    so calling setup at the end to add the devices back to avoid the confusion.
    [Tags]    functionalDt    DisableDeleteONUOLTDt
    [Setup]    Run Keywords    Start Logging    DisableDeleteONUOLTDt
    ...        AND    Run Keyword If    ${has_dataplane}    Set Non-Critical Tag for XGSPON Tech
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DisableDeleteONUOLTDt
    @{onu_reason}=    Create List    initial-mib-downloaded    omci-flows-pushed
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=${onu_reason}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['olt']}
        Disable Device    ${onu_device_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=false
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['olt']}
    END
    # Disable all OLTs
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    voltctl -c ${VOLTCTL_CONFIG} device disable ${olt_device_id}
        Should Be Equal As Integers    ${rc}    0
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
        ...    ${olt_serial_number}
    END
    # Validate ONUs after OLT disable
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=false
        Delete Device    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['olt']}
    END
    # Delete all OLTs
    Delete All Devices and Verify

    #Delete Device    ${olt_device_id}
    #TODO: Fix the following assertion
    #Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Test Empty Device List
    #Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    #...    Verify Device Flows Removed    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}

    # Re-do Setup (Recreate the OLT) and Perform Sanity Test DT
    Run Keyword    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT

Test Disable and Enable OLT PON Port for DT
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Assuming that all the ONUs are DHCP/pingable (i.e. assuming sanityDt test was executed)
    ...    Perform disable on the OLT PON Port and validate that the pings do not succeed
    ...    Perform enable on the OLT PON Port and validate that the pings are successful
    [Tags]    functionalDt    DisableEnableOltPonPortDt    VOL-2577    soak
    [Setup]    Run Keywords    Start Logging   DisableEnableOltPonPortDt
    ...        AND    Run Keyword If    ${has_dataplane}    Set Non-Critical Tag for XGSPON Tech
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DisableEnableOltPonPortDt
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        Disable Enable PON Port Per OLT DT    ${olt_serial_number}
    END

Test ONU Delete and Auto-Discovery for DT
    [Documentation]    Tests the voltctl delete and Auto-Discovery of the ONU
    [Tags]    functionalDt    VOL-3098    ONUAutoDiscoveryDt
    [Setup]    Start Logging   ONUAutoDiscoveryDt
    ...        AND    Verify Ofagent Pod Availablity
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    ONUAutoDiscoveryDt
    Clear All Devices Then Create New Device
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test DT
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        # Remove Subscriber
        Delete Request    VGC    services/${of_id}/${onu_port}
        # Additional sleep to let subscriber delete process
        Sleep    10s
        # Delete ONU and Verify Ping Fails
        Delete Device    ${onu_device_id}
        Run Keyword If    ${has_dataplane}    Verify ping is successful except for given device
        ...    ${num_all_onus}    ${src['onu']}
        # Verify that no pending flows exist for the ONU port
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${onu_port}
        # ONU Auto-Discovery
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}    ${src['uni_id']}
        # Check ONU port is Enabled in VGC
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify UNI Port Is Enabled    ${src['onu']}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Run Keyword If    ${has_dataplane}    Clean Up Linux    ${onu_device_id}
        # Re-Add Subscriber
        Add Subscriber Details    ${of_id}     ${onu_port}
        #Post Request    VGC    services/${of_id}/${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify that no pending flows exist for the ONU port
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT in VGC   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        # Verify Meters in VGC
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Meters in VGC Ietf    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END
    # Verify flows for all OLTs
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate All OLT Flows

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #Restore all ONUs
    #Run Keyword If    ${has_dataplane}    RestoreONUs    ${num_all_onus}
    #power_switch.robot needs it to support different vendor's power switch
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    Scale Down Ofagent Pod

Setup Teardown
    Scale K8s Deployment by Pod Label    ${NAMESPACE}    app    ${OFAGENT_POD}    1
    Wait Until Keyword Succeeds    ${timeout}    2s    Pods Do Not Exist By Label    ${NAMESPACE}    app
    ...    ${OFAGENT_POD}
    Sleep    10s
    Teardown Suite

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and VGC
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup

Scale Down Ofagent Pod
    Scale K8s Deployment by Pod Label    ${NAMESPACE}    app    ${OFAGENT_POD}    0
    Wait Until Keyword Succeeds    ${timeout}    2s    Pods Do Not Exist By Label    ${NAMESPACE}    app
    ...    ${OFAGENT_POD}
    Sleep    10s

Verify Ofagent Pod Availablity
    ${output}=    Pods Do Not Exist By Label    ${NAMESPACE}    app    ${OFAGENT_POD}
    Run Keyword If    "${output}"!="True"    Scale Down Ofagent Pod
