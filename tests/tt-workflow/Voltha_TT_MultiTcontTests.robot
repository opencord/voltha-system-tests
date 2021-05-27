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
Test that the BW is limited to Limiting Bandwidth
    [Documentation]    Verify support for Tcont type 1.
    ...    Verify that traffic is limited to Limiting Bandwidth (eir+cir+air) configured for the service/onu.
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
    ${limiting_bw_value_upstream}=    Get Limiting Bandwidth Details    ${test_us_bw_profile}
    # Stream UDP packets from RG to server
    ${updict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
    ...    args=-u -b 500M -t 30 -p 5201
    # With UDP test, bits per second is the sending rate.  Multiply by the loss rate to get the throughput.
    ${actual_upstream_bw_used}=    Evaluate
    ...    (100 - ${updict['end']['sum']['lost_percent']})*${updict['end']['sum']['bits_per_second']}/100000
    ${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${limiting_bw_value_upstream}
    Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
    ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)

Test that assured BW is allocated as needed on the PON
    [Documentation]    Verify support for Tcont type 2 and 4.
    ...    Verify that the BW from tcont type 4 is bequeathed to type2 as needed.
    ...    1) Pump 1Gbps in the upstream from the RG for HSIA service and verify that no more than 1Gbps is received at the BNG.
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
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test TT

    # The test expects the first entry in multi_tcont_tests.tcont2tcont4 input will be for service: vod and tcont: 2
    # The test expects the second entry in multi_tcont_tests.tcont2tcont4 input will be for service: hsia and tcont: 4
    ${list_onus_ut}=    Create List
    ${num_multi_tcont_input}=    Get Length    ${multi_tcont_tests.tcont2tcont4}
    FOR    ${I}    IN RANGE    0    ${num_multi_tcont_input}
        ${onu}=    Set Variable    ${multi_tcont_tests.tcont2tcont4[${I}]}
        ${onu_sn}=    Set Variable    ${onu['onu']}
        ${service}=    Set Variable    ${onu['service_type']}
        ${us_bw}=    Set Variable    ${onu['us_bw_profile']}
        ${matched}    ${src}    ${dst}=    Get ONU details with Given Sn and Service    ${onu_sn}
        ...    ${service}    ${us_bw}
        Pass Execution If    '${matched}' != 'True'
        ...    Skipping test: No ONU found with sn '${onu_sn}', service '${service}' and us_bw '${us_bw}'
        # Check for iperf3 and jq tools
        ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf3 jq
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Pass Execution If    ${rc} != 0    Skipping test: iperf3 / jq not found on the RG
        # Get Upstream BW Profile details
        ${limiting_bw_us}=    Get Limiting Bandwidth Details    ${us_bw}
        ${onu_ut}    Create Dictionary    src    ${src}    dst    ${dst}    limiting_bw_us    ${limiting_bw_us}
        Append To List    ${list_onus_ut}    ${onu_ut}
    END

    # Case 1: Verify only for HSIA service
    ${dst}=    Set Variable    ${list_onus_ut}[1][dst]
    ${updict}=    Run Iperf3 Test Client    ${list_onus_ut}[1][src]    server=${dst['dp_iface_ip_qinq']}
    ...    args=-t 30 -p 5202
    ${actual_upstream_bw_used}=    Evaluate    ${updict['end']['sum_received']['bits_per_second']}/1000
    ${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${list_onus_ut}[1][limiting_bw_us]
    Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
    ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)

    # Case 2: Verify for VOD (with index [0]) and HSIA (with index [1]) service combined
    ${out_file_0}=    Set Variable    ${CURDIR}/../../tests/data/out_tcont2
    ${dst_0}=    Set Variable    ${list_onus_ut}[0][dst]
    Run Iperf3 Test Client in Background    ${list_onus_ut}[0][src]    server=${dst_0['dp_iface_ip_qinq']}
    ...    args=-t 30 -p 5201    out_file=${out_file_0}
    ${out_file_1}=    Set Variable    ${CURDIR}/../../tests/data/out_tcont4
    ${dst_1}=    Set Variable    ${list_onus_ut}[1][dst]
    Run Iperf3 Test Client in Background    ${list_onus_ut}[1][src]    server=${dst_1['dp_iface_ip_qinq']}
    ...    args=-t 30 -p 5202    out_file=${out_file_1}
    # Wait for the above iperf commands to finish (sleep time depends on -t arg value passed in iperf command)
    Sleep    35s
    ${out_0}=    Read Output File on System    ${out_file_0}
    ${out_1}=    Read Output File on System    ${out_file_1}
    ${actual_upstream_bw_used_0}=    Evaluate    ${out_0['end']['sum_received']['bits_per_second']}/1000
    ${pct_limit_up_0}=    Evaluate    100*${actual_upstream_bw_used_0}/${list_onus_ut}[0][limiting_bw_us]
    Should Be True    ${pct_limit_up_0} >= ${lower_margin_pct}
    ...    The upstream bandwidth guarantee was not met (${pct_limit_up_0}% of resv)
    ${actual_upstream_bw_used_1}=    Evaluate    ${out_1['end']['sum_received']['bits_per_second']}/1000
    ${pct_limit_up_1}=    Evaluate
    ...    100*${actual_upstream_bw_used_1}/(${list_onus_ut}[1][limiting_bw_us]-${list_onus_ut}[0][limiting_bw_us])
    Should Be True    ${pct_limit_up_1} >= ${lower_margin_pct}
    ...    The upstream bandwidth guarantee was not met (${pct_limit_up_1}% of resv)

*** Keywords ***
Read Output File on System
    [Arguments]    ${file}
    [Documentation]    Reads the content of ${file}.
    ${output}=    OperatingSystem.Get File    ${file}
    Log    ${output}
    ${object}=    Evaluate    json.loads(r'''${output}''')    json
    [Return]    ${object}

Run Iperf3 Test Client in Background
    [Arguments]    ${src}    ${server}    ${args}    ${out_file}
    [Documentation]    Login to ${src} and run the iperf3 client against ${server} using ${args} in background.
    ...    Stores the results of the test in ${out_file}.
    ${output}    ${stderr}    ${rc}=    Execute Remote Command    iperf3 -J -c ${server} ${args} > ${out_file} &
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Should Be Equal As Integers    ${rc}    0

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
        ...    ${service_type}
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
