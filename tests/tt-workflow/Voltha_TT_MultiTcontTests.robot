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
    ...
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Tests TT
    # The test expectes first ONU with service type voip must be present at index 2 of pod deployment yaml
    ${src}=    Set Variable    ${hosts.src[2]}
    ${dst}=    Set Variable    ${hosts.dst[2]}
    ${service_type}=    Get Variable Value    ${src['service_type']}    "null"
    Should Be Equal As Strings    '${service_type}'    'voip'    Service type required for this test is voip.
    ${of_id}=    Get ofID From OLT List    ${src['olt']}
    # Check for iperf3 and jq tools
    ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf3 jq
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Pass Execution If    ${rc} != 0    Skipping test: iperf3 / jq not found on the RG
    ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
    ...    ${of_id}
    ${subscriber_id}=    Set Variable    ${of_id}/${onu_port}
    ${bandwidth_profile_name}    Get Bandwidth Profile Name For Given Subscriber    ${subscriber_id}
    ...    upstreamBandwidthProfile
    Should Be Equal As Strings    ${bandwidth_profile_name}    'TCONT_TYPE1_200Mbps_Fixed_ForVOIP'    Invalid BW Profile
    ${us_cir}    ${us_cbs}    ${us_pir}    ${us_pbs}    ${us_gir}=    Get Bandwidth Profile Details Ietf Rest
    ...    ${bandwidth_profile_name}
    # Stream UDP packets from RG to server
    ${updict}=    Run Iperf3 Test Client    ${src}    server=${dst['dp_iface_ip_qinq']}
    ...    args=-u -b 500M -t 30
    # With UDP test, bits per second is the sending rate.  Multiply by the loss rate to get the throughput.
    ${actual_upstream_bw_used}=    Evaluate
    ...    (100 - ${updict['end']['sum']['lost_percent']})*${updict['end']['sum']['bits_per_second']}/1000
    ${pct_limit_up}=    Evaluate    100*${actual_upstream_bw_used}/${us_gir}
    Should Be True    ${pct_limit_up} >= ${lower_margin_pct}
    ...    The upstream bandwidth guarantee was not met (${pct_limit_up}% of resv)

*** Keywords ***
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
