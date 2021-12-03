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
Documentation     Test various multicast scenarios with given input file for TT workflow
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
${INFRA_NAMESPACE}      default
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${multicast_test_duration}     60
${has_dataplane}    True
${teardown_device}    True
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

${suppressaddsubscriber}    True

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

*** Test Cases ***
2 RG Same ONU Same Channel Multicast Test
    [Documentation]    Verify that 2 RG which are connected to the same ONU could join the same channel.
    [Tags]    functionalTT    2RGSameOnuSameChannel    multicastTT
    [Setup]    Start Logging    2RGSameOnuSameChannel
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    2RGSameOnuSameChannel
    ${test_onus_pon0}=    Set Variable    ${multicast_test_onu_pon_locations.pon_0[0]}
    ${test_onu1_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu1_uni}=    Set Variable    1
    ${test_onu2_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu2_uni}=    Set Variable    2
    ${channel_ip_list}=    Set Variable    ${multicast_ip_addresses[0]}
    ${channel_ip_1}=    Set Variable    ${channel_ip_list['channel_1']}
    ${matched}    ${src_onu1}    ${dst_onu1}=    Get ONU details with Given Sn and Service and UNI    ${test_onu1_sn}    mcast
    ...    ${test_onu1_uni}
    ${matched}    ${src_onu2}    ${dst_onu2}=    Get ONU details with Given Sn and Service and UNI    ${test_onu2_sn}    mcast
    ...    ${test_onu2_uni}
    Wait Until Keyword Succeeds    ${timeout}    15    TT 2 RG MCAST Test    ${src_onu1}    ${dst_onu1}
    ...    ${channel_ip_1}    ${src_onu2}    ${dst_onu2}    ${channel_ip_1}    ${multicast_test_duration}
    # The purpose of this sleep period is to ensure that all groups and flows are deleted from the OLT before the next test.
    Sleep    ${multicast_test_duration}

2 RG Same ONU Different Channel Multicast Test
    [Documentation]    Verify that 2 RG which are connected to the same ONU could join the different channel.
    [Tags]    functionalTT    2RGSameOnuDifferentChannel    multicastTT
    [Setup]    Start Logging    2RGSameOnuDifferentChannel
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    2RGSameOnuDifferentChannel
    ${test_onus_pon0}=    Set Variable    ${multicast_test_onu_pon_locations.pon_0[0]}
    ${test_onu1_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu1_uni}=    Set Variable    1
    ${test_onu2_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu2_uni}=    Set Variable    2
    ${channel_ip_list}=    Set Variable    ${multicast_ip_addresses[0]}
    ${channel_ip_1}=    Set Variable    ${channel_ip_list['channel_1']}
    ${channel_ip_2}=    Set Variable    ${channel_ip_list['channel_2']}
    ${matched}    ${src_onu1}    ${dst_onu1}=    Get ONU details with Given Sn and Service and UNI    ${test_onu1_sn}    mcast
    ...    ${test_onu1_uni}
    ${matched}    ${src_onu2}    ${dst_onu2}=    Get ONU details with Given Sn and Service and UNI    ${test_onu2_sn}    mcast
    ...    ${test_onu2_uni}
    Wait Until Keyword Succeeds    ${timeout}    15    TT 2 RG MCAST Test    ${src_onu1}    ${dst_onu1}
    ...    ${channel_ip_1}    ${src_onu2}    ${dst_onu2}    ${channel_ip_2}    ${multicast_test_duration}
    # The purpose of this sleep period is to ensure that all groups and flows are deleted from the OLT before the next test.
    Sleep    ${multicast_test_duration}

2 RG Same PON Different ONU Same Channel Multicast Test
    [Documentation]    Verify that 2 RG which are connected to the different ONUs
    ...    on the same PON Ports could join the same channel.
    [Tags]    functionalTT    2RGSamePonDifferentOnuSameChannel    multicastTT
    [Setup]    Start Logging    2RGSamePonDifferentOnuSameChannel
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    2RGSamePonDifferentOnuSameChannel
    ${test_onus_pon0}=    Set Variable    ${multicast_test_onu_pon_locations.pon_0[0]}
    ${test_onu1_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu1_uni}=    Set Variable    1
    ${test_onu2_sn}=    Set Variable    ${test_onus_pon0['onu_2']}
    ${test_onu2_uni}=    Set Variable    1
    ${channel_ip_list}=    Set Variable    ${multicast_ip_addresses[0]}
    ${channel_ip_1}=    Set Variable    ${channel_ip_list['channel_1']}
    ${matched}    ${src_onu1}    ${dst_onu1}=    Get ONU details with Given Sn and Service and UNI    ${test_onu1_sn}    mcast
    ...    ${test_onu1_uni}
    ${matched}    ${src_onu2}    ${dst_onu2}=    Get ONU details with Given Sn and Service and UNI    ${test_onu2_sn}    mcast
    ...    ${test_onu2_uni}
    Wait Until Keyword Succeeds    ${timeout}    15    TT 2 RG MCAST Test    ${src_onu1}    ${dst_onu1}
    ...    ${channel_ip_1}    ${src_onu2}    ${dst_onu2}    ${channel_ip_1}    ${multicast_test_duration}
    # The purpose of this sleep period is to ensure that all groups and flows are deleted from the OLT before the next test.
    Sleep    ${multicast_test_duration}

2 RG Same PON Different ONU Different Channels Multicast Test
    [Documentation]    Verify that 2 RG which are connected to the different ONUs
    ...    on the same PON Ports could join the different channels.
    [Tags]    functionalTT    2RGSamePonDifferentOnuDifferentChannel    multicastTT
    [Setup]    Start Logging    2RGSamePonDifferentOnuDifferentChannel
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    2RGSamePonDifferentOnuDifferentChannel
    ${test_onus_pon0}=    Set Variable    ${multicast_test_onu_pon_locations.pon_0[0]}
    ${test_onu1_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu1_uni}=    Set Variable    1
    ${test_onu2_sn}=    Set Variable    ${test_onus_pon0['onu_2']}
    ${test_onu2_uni}=    Set Variable    1
    ${channel_ip_list}=    Set Variable    ${multicast_ip_addresses[0]}
    ${channel_ip_1}=    Set Variable    ${channel_ip_list['channel_1']}
    ${channel_ip_2}=    Set Variable    ${channel_ip_list['channel_2']}
    ${matched}    ${src_onu1}    ${dst_onu1}=    Get ONU details with Given Sn and Service and UNI    ${test_onu1_sn}    mcast
    ...    ${test_onu1_uni}
    ${matched}    ${src_onu2}    ${dst_onu2}=    Get ONU details with Given Sn and Service and UNI    ${test_onu2_sn}    mcast
    ...    ${test_onu2_uni}
    Wait Until Keyword Succeeds    ${timeout}    15    TT 2 RG MCAST Test    ${src_onu1}    ${dst_onu1}
    ...    ${channel_ip_1}    ${src_onu2}    ${dst_onu2}    ${channel_ip_2}    ${multicast_test_duration}
    # The purpose of this sleep period is to ensure that all groups and flows are deleted from the OLT before the next test.
    Sleep    ${multicast_test_duration}

2 RG Different PON Different ONU Same Channel Multicast Test
    [Documentation]    Verify that 2 RG which are connected to the different ONUs
    ...    on the different PON Ports could join the same channel.
    [Tags]    functionalTT    2RGDifferentOnuandPonSameChannel    multicastTT   notready
    [Setup]    Start Logging    2RGDifferentOnuandPonSameChannel
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    2RGDifferentOnuandPonSameChannel
    ${test_onus_pon0}=    Set Variable    ${multicast_test_onu_pon_locations.pon_0[0]}
    ${test_onus_pon1}=    Set Variable    ${multicast_test_onu_pon_locations.pon_1[0]}
    ${test_onu1_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu1_uni}=    Set Variable    1
    ${test_onu2_sn}=    Set Variable    ${test_onus_pon1['onu_1']}
    ${test_onu2_uni}=    Set Variable    1
    ${channel_ip_list}=    Set Variable    ${multicast_ip_addresses[0]}
    ${channel_ip_1}=    Set Variable    ${channel_ip_list['channel_1']}
    ${matched}    ${src_onu1}    ${dst_onu1}=    Get ONU details with Given Sn and Service and UNI    ${test_onu1_sn}    mcast
    ...    ${test_onu1_uni}
    ${matched}    ${src_onu2}    ${dst_onu2}=    Get ONU details with Given Sn and Service and UNI    ${test_onu2_sn}    mcast
    ...    ${test_onu2_uni}
    Wait Until Keyword Succeeds    ${timeout}    15    TT 2 RG MCAST Test    ${src_onu1}    ${dst_onu1}
    ...    ${channel_ip_1}    ${src_onu2}    ${dst_onu2}    ${channel_ip_1}    ${multicast_test_duration}
    # The purpose of this sleep period is to ensure that all groups and flows are deleted from the OLT before the next test.
    Sleep    ${multicast_test_duration}

2 RG Different PON Different ONU Different Channels Multicast Test
    [Documentation]    Verify that 2 RG which are connected to the different ONUs
    ...    on the different PON Ports could join the different channels.
    [Tags]    functionalTT    2RGDifferentOnuandPonDifferentChannels    multicastTT   notready
    [Setup]    Start Logging    2RGDifferentOnuandPonDifferentChannels
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    2RGDifferentOnuandPonDifferentChannels
    ${test_onus_pon0}=    Set Variable    ${multicast_test_onu_pon_locations.pon_0[0]}
    ${test_onus_pon1}=    Set Variable    ${multicast_test_onu_pon_locations.pon_1[0]}
    ${test_onu1_sn}=    Set Variable    ${test_onus_pon0['onu_1']}
    ${test_onu1_uni}=    Set Variable    1
    ${test_onu2_sn}=    Set Variable    ${test_onus_pon1['onu_1']}
    ${test_onu2_uni}=    Set Variable    1
    ${channel_ip_list}=    Set Variable    ${multicast_ip_addresses[0]}
    ${channel_ip_1}=    Set Variable    ${channel_ip_list['channel_1']}
    ${channel_ip_2}=    Set Variable    ${channel_ip_list['channel_2']}
    ${matched}    ${src_onu1}    ${dst_onu1}=    Get ONU details with Given Sn and Service and UNI    ${test_onu1_sn}    mcast
    ...    ${test_onu1_uni}
    ${matched}    ${src_onu2}    ${dst_onu2}=    Get ONU details with Given Sn and Service and UNI    ${test_onu2_sn}    mcast
    ...    ${test_onu2_uni}
    Wait Until Keyword Succeeds    ${timeout}    15    TT 2 RG MCAST Test    ${src_onu1}    ${dst_onu1}
    ...    ${channel_ip_1}    ${src_onu2}    ${dst_onu2}    ${channel_ip_2}    ${multicast_test_duration}

*** Keywords ***
Get ONU details with Given Sn and Service and UNI
    [Documentation]    This keyword finds the ONU details (as required for multicast test)
    ...    with given serial number, service type and UNI
    [Arguments]    ${onu_sn}    ${service_type}    ${uni}
    ${matched}=    Set Variable    False
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${service}=    Get Variable Value    ${src['service_type']}    "null"
        ${onu}=    Get Variable Value    ${src['onu']}    "null"
        ${uni_id}=    Get Variable Value    ${src['uni_id']}    "null"
        Continue For Loop If    '${onu}' != '${onu_sn}' or '${service}' != '${service_type}'
        ${matched}=    Set Variable If
        ...    '${onu}' == '${onu_sn}' and '${service}' == '${service_type}' and '${uni}' == '${uni_id}'
        ...    True    False
        Exit For Loop If    ${matched}
    END
    [Return]    ${matched}    ${src}    ${dst}


TT 2 RG MCAST Test
    [Documentation]    This keyword performs MCAST two RG at the Same Time for TT workflow.
    ...    RG1 and RG2 could be join same channel or different channel.
    ...    It will run multicast test with given multicast_test_duration variable.
    ...    RG2 will leave channel after multicast_test_duration/2 seconds.
    ...    Function verify that RG1's multicast stream is not affected.
    [Arguments]    ${src_rg1}    ${dst_rg1}    ${channel_ip_rg1}    ${src_rg2}    ${dst_rg2}    ${channel_ip_rg2}
    ...    ${multicast_test_duration}
    # Check for iperf and jq tools RG1
    ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf jq
    ...    ${src_rg1['ip']}    ${src_rg1['user']}    ${src_rg1['pass']}    ${src_rg1['container_type']}
    ...    ${src_rg1['container_name']}
    Pass Execution If    ${rc} != 0    Skipping test: iperf / jq not found on the RG

    # Check for iperf and jq tools RG2
    ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf jq
    ...    ${src_rg2['ip']}    ${src_rg2['user']}    ${src_rg2['pass']}    ${src_rg2['container_type']}
    ...    ${src_rg2['container_name']}
    Pass Execution If    ${rc} != 0    Skipping test: iperf / jq not found on the RG

    #Reset the IP on the interface RG1
    ${output}=    Login And Run Command On Remote System    sudo ifconfig ${src_rg1['dp_iface_name']} 0
    ...    ${src_rg1['ip']}    ${src_rg1['user']}    ${src_rg1['pass']}    ${src_rg1['container_type']}
    ...    ${src_rg1['container_name']}
    # Kill iperf  on BNG
    ${rg_output}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf`
    ...    ${dst_rg1['bng_ip']}    ${dst_rg1['bng_user']}    ${dst_rg1['bng_pass']}    ${dst_rg1['container_type']}
    ...    ${dst_rg1['container_name']}

    #Reset the IP on the interface RG2
    ${output}=    Login And Run Command On Remote System    sudo ifconfig ${src_rg1['dp_iface_name']} 0
    ...    ${src_rg2['ip']}    ${src_rg2['user']}    ${src_rg2['pass']}    ${src_rg2['container_type']}
    ...    ${src_rg2['container_name']}
    # Kill iperf  on BNG
    ${rg_output}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf`
    ...    ${dst_rg2['bng_ip']}    ${dst_rg2['bng_user']}    ${dst_rg2['bng_pass']}    ${dst_rg2['container_type']}
    ...    ${dst_rg2['container_name']}

    # Setup RG1 for Multi-cast test
    ${output}=    Login And Run Command On Remote System
    ...    sudo ifconfig ${src_rg1['dp_iface_name']} ${src_rg1['mcast_rg']} up ; sudo kill -9 `pidof iperf`
    ...    ${src_rg1['ip']}    ${src_rg1['user']}    ${src_rg1['pass']}    ${src_rg1['container_type']}
    ...    ${src_rg1['container_name']}
    ${output}=    Login And Run Command On Remote System
    ...    sudo ip route add ${src_rg1['mcast_grp_subnet_mask']} dev ${src_rg1['dp_iface_name']} scope link
    ...    ${src_rg1['ip']}    ${src_rg1['user']}    ${src_rg1['pass']}    ${src_rg1['container_type']}
    ...    ${src_rg1['container_name']}

    # Setup RG2 for Multi-cast test
    ${output}=    Login And Run Command On Remote System
    ...    sudo ifconfig ${src_rg2['dp_iface_name']} ${src_rg2['mcast_rg']} up ; sudo kill -9 `pidof iperf`
    ...    ${src_rg2['ip']}    ${src_rg2['user']}    ${src_rg2['pass']}    ${src_rg2['container_type']}
    ...    ${src_rg2['container_name']}
    ${output}=    Login And Run Command On Remote System
    ...    sudo ip route add ${src_rg2['mcast_grp_subnet_mask']} dev ${src_rg2['dp_iface_name']} scope link
    ...    ${src_rg2['ip']}    ${src_rg2['user']}    ${src_rg2['pass']}    ${src_rg2['container_type']}
    ...    ${src_rg2['container_name']}

    # Setup iperf on the BNG
    ${server_output}=    Run Keyword If    '${channel_ip_rg1}'=='${channel_ip_rg2}'
    ...    Login And Run Command On Remote System
    ...    sudo iperf -c '${channel_ip_rg1}' -u -T 32 -t ${multicast_test_duration} -i 1 &
    ...    ${dst_rg1['bng_ip']}    ${dst_rg1['bng_user']}    ${dst_rg1['bng_pass']}    ${dst_rg1['container_type']}
    ...    ${dst_rg1['container_name']}
    ...    ELSE    Run Keywords    Run Keyword And Continue On Failure
    ...    Login And Run Command On Remote System
    ...    sudo iperf -c '${channel_ip_rg1}' -u -T 32 -t ${multicast_test_duration} -i 1 &
    ...    ${dst_rg1['bng_ip']}    ${dst_rg1['bng_user']}    ${dst_rg1['bng_pass']}    ${dst_rg1['container_type']}
    ...    ${dst_rg1['container_name']}     AND    Run Keyword And Continue On Failure
    ...    Login And Run Command On Remote System
    ...    sudo iperf -c '${channel_ip_rg2}' -u -T 32 -t ${multicast_test_duration} -i 1 &
    ...    ${dst_rg2['bng_ip']}    ${dst_rg2['bng_user']}    ${dst_rg2['bng_pass']}    ${dst_rg2['container_type']}
    ...    ${dst_rg2['container_name']}

    # Setup iperf on the RG1
    ${rg_output_rg1}=    Run Keyword and Continue On Failure    Wait Until Keyword Succeeds     ${timeout}    5s
    ...    Login And Run Command On Remote System
    ...    rm -rf /tmp/rg1_output ; date >> /tmp/rg1_output ; sudo iperf -s -u -B '${channel_ip_rg1}' -i 1 -D >> /tmp/rg1_output
    ...    ${src_rg1['ip']}    ${src_rg1['user']}    ${src_rg1['pass']}    ${src_rg1['container_type']}
    ...    ${src_rg1['container_name']}

    # Setup iperf on the RG2
    ${rg_output_rg2}=    Run Keyword and Continue On Failure    Wait Until Keyword Succeeds     ${timeout}    5s
    ...    Login And Run Command On Remote System
    ...    rm -rf /tmp/rg2_output ; date >> /tmp/rg2_output ; sudo iperf -s -u -B '${channel_ip_rg2}' -i 1 -D >> /tmp/rg2_output
    ...    ${src_rg2['ip']}    ${src_rg2['user']}    ${src_rg2['pass']}    ${src_rg2['container_type']}
    ...    ${src_rg2['container_name']}

    #Logging Outputs and Check iperf UDP Stream Outputs
    Log    ${rg_output_rg1}
    Log    ${rg_output_rg2}
    ${igmp_leave_time}=     Evaluate    ${multicast_test_duration}/2
    ${s}=    Set Variable   s
    ${sleep_time}=    Set Variable   ${igmp_leave_time}${s}
    Sleep    ${sleep_time}
    ${onos_delay_tolerance}=    Set Variable   5
    ${igmp_leave_time_with_delay}=     Evaluate    ${igmp_leave_time} + ${onos_delay_tolerance}

    # Kill iperf on the RG2
    ${rg_kill_output_rg2}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf` ; date >> /tmp/rg2_output    ${src_rg2['ip']}    ${src_rg2['user']}
    ...    ${src_rg2['pass']}    ${src_rg2['container_type']}    ${src_rg2['container_name']}

    Sleep    ${sleep_time}

    # Kill iperf on the RG1
    ${output}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf` ; date >> /tmp/rg1_output    ${src_rg1['ip']}    ${src_rg1['user']}
    ...    ${src_rg1['pass']}    ${src_rg1['container_type']}    ${src_rg1['container_name']}

    ${output_rg1}=    Run Keyword and Continue On Failure     Wait Until Keyword Succeeds     ${timeout}    5s
    ...    Login And Run Command On Remote System
    ...    cat /tmp/rg1_output | grep KBytes
    ...    ${src_rg1['ip']}    ${src_rg1['user']}    ${src_rg1['pass']}    ${src_rg1['container_type']}
    ...    ${src_rg1['container_name']}
    Log    ${output_rg1}
    # Check that RG1's stream count
    ${output_rg1_count}=    Get Line Count    ${output_rg1}
    ${output_rg1_count}=    Evaluate    ${output_rg1_count}-1
    ${output_rg1_file}=    Run Keyword and Continue On Failure     Wait Until Keyword Succeeds     ${timeout}    5s
    ...    Login And Run Command On Remote System
    ...    cat /tmp/rg1_output
    ...    ${src_rg1['ip']}    ${src_rg1['user']}    ${src_rg1['pass']}    ${src_rg1['container_type']}
    ...    ${src_rg1['container_name']}
    Log    ${output_rg1_file}


    ${output_rg2}=    Run Keyword and Continue On Failure     Wait Until Keyword Succeeds     ${timeout}    5s
    ...    Login And Run Command On Remote System
    ...    cat /tmp/rg2_output | grep KBytes
    ...    ${src_rg2['ip']}    ${src_rg2['user']}    ${src_rg2['pass']}    ${src_rg2['container_type']}
    ...    ${src_rg2['container_name']}
    Log    ${output_rg2}
    # Check that RG2's stream count
    ${output_rg2_count}=    Get Line Count      ${output_rg2}
    ${output_rg2_count}=    Evaluate    ${output_rg2_count}-1
    ${output_rg2_file}=    Run Keyword and Continue On Failure     Wait Until Keyword Succeeds     ${timeout}    5s
    ...    Login And Run Command On Remote System
    ...    cat /tmp/rg2_output
    ...    ${src_rg2['ip']}    ${src_rg2['user']}    ${src_rg2['pass']}    ${src_rg2['container_type']}
    ...    ${src_rg2['container_name']}
    Log    ${output_rg2_file}

    # Kill iperf  on BNG
    ${server_output}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf`
    ...    ${dst_rg1['bng_ip']}    ${dst_rg1['bng_user']}    ${dst_rg1['bng_pass']}    ${dst_rg1['container_type']}
    ...    ${dst_rg1['container_name']}


    Should Contain    ${output_rg1}    KBytes
    Should Contain    ${output_rg2}    KBytes
    # Verify that RG1's stream count is lower than multicast total test duration
    Should Be Lower Than    ${output_rg1_count}    ${multicast_test_duration}
    # Verify that RG1's stream count is larger than multicast igmp leave time
    Should Be Larger Than    ${output_rg1_count}    ${igmp_leave_time_with_delay}
    # Verify that RG2's stream count is lower than multicast igmp leave time
    Should Be Lower Than    ${output_rg2_count}    ${igmp_leave_time_with_delay}


Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword    Setup
    Wait Until Keyword Succeeds    ${timeout}    2s    Provision Subscription TT


Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup
