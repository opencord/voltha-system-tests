# Copyright 2021 - present Open Networking Foundation
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

# For dataplane bandwidth testing
${lower_margin_pct}      90      # Allow 10% under the limit

*** Test Cases ***
Test that the BW is limited to GIR
    [Documentation]    Verify support for Tcont type 1.
    ...    Verify that traffic is limited to GIR configured for the service/onu.
    ...    Pump 500Mbps in the upstream from RG and verify that the received traffic is only 200Mbps at the BNG.
    ...    Note: Currently, only Flex Pod supports the deployment configuration required to test this scenario.
    [Tags]    functionalTT    VOL-4093
    [Setup]    Run Keywords    Start Logging    TcontType1Onu1
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    TcontType1Onu1
    ...           AND             Delete All Devices and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT
    # Find the ONU as required for this test
    ${test_onu}=    Set Variable    ${multi_tcont_tests.tcont1[0]}
    ${test_onu_sn}=    Set Variable    ${test_onu['onu']}
    ${test_service_type}=    Set Variable    ${test_onu['service_type']}
    ${test_us_bw_profile}=    Set Variable    ${test_onu['us_bw_profile']}
    ${matched}    ${src}    ${dst}=    Get ONU details with Given Sn and Service    ${test_onu_sn}    ${test_service_type}
    ...    ${test_us_bw_profile}
    Pass Execution If    '${matched}' != 'True'
    ...    Skipping test: No ONU found with sn '${test_onu_sn}', service '${test_service_type}' and us_bw '${test_us_bw_profile}'
    # Check for iperf3 and jq tools
    ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf3 jq
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Pass Execution If    ${rc} != 0    Skipping test: iperf3 / jq not found on the RG
    ${us_cir}    ${us_cbs}    ${us_pir}    ${us_pbs}    ${us_gir}=    Get Bandwidth Profile Details Ietf Rest
    ...    ${test_us_bw_profile}
    # Stream UDP packets from RG to server
    ${updict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
    ...    args=-u -b 500M -t 30 -p 5201
    # With UDP test, bits per second is the sending rate.  Multiply by the loss rate to get the throughput.
    ${actual_upstream_bw_used}=    Evaluate
    ...    (100 - ${updict['end']['sum']['lost_percent']})*${updict['end']['sum']['bits_per_second']}/100000
    ${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${us_gir}
    Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
    ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)

Test that assured BW is allocated as needed on the PON
    [Documentation]    Verify support for Tcont type 2 and 4.
    ...    Verify that the BW from tcont type 4 is bequeathed to type2 as needed.
    ...    1) Pump 1Gbps in the upstream from the RG for HSI service and verify that no more than 1Gbps is received at the BNG.
    ...    2) Pump 500Mbps from the RG for the VoD service and verify that close to 500Mbps is received at the BNG.
    ...    Also, verify that the HSI rate is now truncated to 500Mbps at BNG.
    ...    Note: Currently, only Flex Pod supports the deployment configuration required to test this scenario.
    [Tags]    functionalTT    VOL-4095
    [Setup]    Run Keywords    Start Logging    TcontType2Type4Onu1
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    TcontType2Type4Onu1
    ...           AND             Delete All Devices and Verify
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT
    # Find 1st record of the ONU (onu_<onu-1/2>_<tcont-1/2/3/4/5>) as required for this test
    ${onu_1_2}=    Set Variable    ${multi_tcont_tests.tcont2tcont4[0]}
    ${onu_sn_1_2}=    Set Variable    ${onu_1_2['onu']}
    ${service_type_1_2}=    Set Variable    ${onu_1_2['service_type']}
    ${us_bw_profile_1_2}=    Set Variable    ${onu_1_2['us_bw_profile']}
    ${matched}    ${src_1_2}    ${dst_1_2}=    Get ONU details with Given Sn and Service    ${onu_sn_1_2}    ${service_type_1_2}
    ...    ${us_bw_profile_1_2}
    Pass Execution If    '${matched}' != 'True'
    ...    Skipping test: No ONU found with sn '${onu_sn_1_2}', service '${service_type_1_2}' and us_bw '${us_bw_profile_1_2}'
    # Check for iperf3 and jq tools
    ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf3 jq
    ...    ${src_1_2['ip']}    ${src_1_2['user']}    ${src_1_2['pass']}    ${src_1_2['container_type']}    ${src_1_2['container_name']}
    Pass Execution If    ${rc} != 0    Skipping test: iperf3 / jq not found on the RG
    # Get Upstream BW Profile details
    ${us_cir_1_2}    ${us_cbs_1_2}    ${us_pir_1_2}    ${us_pbs_1_2}    ${us_gir_1_2}=    Get Bandwidth Profile Details Ietf Rest
    ...    ${us_bw_profile_1_2}
    # Find 2nd record of the ONU (onu_<onu-1/2>_<tcont-1/2/3/4/5>) as required for this test
    ${onu_1_4}=    Set Variable    ${multi_tcont_tests.tcont2tcont4[1]}
    ${onu_sn_1_4}=    Set Variable    ${onu_1_4['onu']}
    ${service_type_1_4}=    Set Variable    ${onu_1_4['service_type']}
    ${us_bw_profile_1_4}=    Set Variable    ${onu_1_4['us_bw_profile']}
    ${matched}    ${src_1_4}    ${dst_1_4}=    Get ONU details with Given Sn and Service    ${onu_sn_1_4}    ${service_type_1_4}
    ...    ${us_bw_profile_1_4}
    Pass Execution If    '${matched}' != 'True'
    ...    Skipping test: No ONU found with sn '${onu_sn_1_4}', service '${service_type_1_4}' and us_bw '${us_bw_profile_1_4}'
    # Check for iperf3 and jq tools
    ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf3 jq
    ...    ${src_1_4['ip']}    ${src_1_4['user']}    ${src_1_4['pass']}    ${src_1_4['container_type']}    ${src_1_4['container_name']}
    Pass Execution If    ${rc} != 0    Skipping test: iperf3 / jq not found on the RG
    # Get Upstream BW Profile details
    ${us_cir_1_4}    ${us_cbs_1_4}    ${us_pir_1_4}    ${us_pbs_1_4}    ${us_gir_1_4}=    Get Bandwidth Profile Details Ietf Rest
    ...    ${us_bw_profile_1_4}
    # Case 1: Verify only for HSIA service
    # Stream UDP packets from RG to server
    ${updict}=    Run Iperf3 Test Client    ${src_1_4}    server=${dst_1_4['dp_iface_ip_qinq']}
    ...    args=-t 30 -p 5202
    ${actual_upstream_bw_used}=    Evaluate    ${updict['end']['sum_received']['bits_per_second']}/1000
    #${actual_upstream_bw_used}=    Evaluate
    #...    (100 - ${updict['end']['sum']['lost_percent']})*${updict['end']['sum']['bits_per_second']}/100000
    #${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${us_gir}
    #Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
    #...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)

*** Keywords ***
Get ONU details with Given Sn and Service
    [Documentation]    This keyword finds the ONU details (as required for multi-tcont test)
    ...    with given serial number and service type
    ...    The keyword, additionally, also verifies the associated upstream bandwidth profile
    [Arguments]    ${onu_sn}    ${service_type}    ${us_bw_profile}
    ${matched}=    Set Variable    False
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${service}=    Get Variable Value    ${src['service_type']}    "null"
        ${onu}=    Get Variable Value    ${src['onu']}    "null"
        Continue For Loop If    '${onu}' != '${onu_sn}' or '${service}' != '${service_type}'
        # Additional verification to check upstream bandwidth profile
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        ${subscriber_id}=    Set Variable    ${of_id}/${onu_port}
        ${us_bw}    Get Bandwidth Profile Name For Given Subscriber    ${subscriber_id}    upstreamBandwidthProfile
        ${matched}=    Set Variable If
        ...    '${onu}' == '${onu_sn}' and '${service}' == '${service_type}' and ${us_bw} == '${us_bw_profile}'
        ...    True    False
        Exit For Loop If    ${matched}
    END
    [Return]    ${matched}    ${src}    ${dst}

Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
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
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${teardown_device}    Delete All Devices And Verify
