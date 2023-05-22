# Copyright 2020-2022 Open Networking Foundation (ONF) and the ONF Contributors
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

*** Settings ***
Documentation     Run tests On BBSim
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite
Test Setup        Setup
Test Teardown     Teardown
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
Resource          ../../libraries/bbsim.robot
Resource          ../../variables/variables.robot

*** Variables ***
${NAMESPACE}      voltha
${INFRA_NAMESPACE}      default
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    False
${external_libs}    True
${teardown_device}    True
${scripts}        ../../scripts
# determines the environment workflow: DT, TT or ATT (default)
# example: -v workflow:TT
${workflow}    ATT
# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}
# Number of times to perform ONU Igmp Join and Leave (valid only for TT)
${igmp_join_leave_count}    1
# Number of times the Sanity test needs to be repeated as
# we want to make sure you can disable/delete the device without needing to restart BBSim
${iteration_count}  2

${suppressaddsubscriber}    True

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

# Igmp group address to perform join and leave for ONUs
${igmp_group_address}    224.0.0.22

*** Test Cases ***

Test Perform BBSim Sanity
    [Documentation]    Validates the BBSim Functionality for ATT, DT and TT workflows
    ...    Also Restart Auth (ATT), Restart Dhcp (ATT and TT), Igmp Join and Leave (TT)
    [Tags]    bbsimSanity
    [Setup]   Run Keyword    Start Logging     BBSimSanity
    FOR    ${I}    IN RANGE    0    ${iteration_count}
        Perform BBSim Sanity Test
    END
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    BBSimSanity

*** Keywords ***

Perform ONU Igmp Join and Leave
    [Documentation]    This keyword performs Igmp Leave and Join for ONU
    [Arguments]    ${bbsim_pod}    ${of_id}    ${onu}    ${onu_port}
    FOR    ${Z}    IN RANGE    0    ${igmp_join_leave_count}
        List Service    ${NAMESPACE}    ${bbsim_pod}
        JoinOrLeave Igmp    ${NAMESPACE}    ${bbsim_pod}    ${onu}    0    join    ${igmp_group_address}
        Sleep    2s
        List Service    ${NAMESPACE}    ${bbsim_pod}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify ONU in Groups    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}    ${onu_port}
        JoinOrLeave Igmp    ${NAMESPACE}    ${bbsim_pod}    ${onu}    0    leave    ${igmp_group_address}
        Sleep    2s
        List Service    ${NAMESPACE}    ${bbsim_pod}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify ONU in Groups    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}    ${onu_port}    False
    END

Perform BBSim Sanity Test
    [Documentation]  Runs the sanity test on multiple OLTs

    Run Keyword    Setup
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Perform BBSim Sanity Test Per OLT    ${bbsim_pod}    ${of_id}    ${olt_serial_number}    ${onu_count}
    END
    Run Keyword  Delete All Devices and Verify

Perform BBSim Sanity Test Per OLT
    [Documentation]    Validates the BBSim Functionality for ATT, DT and TT workflows
    ...    Also Restart Auth (ATT), Restart Dhcp (ATT and TT), Igmp Join and Leave (TT)
    ...    Once the ONU tests are completed perform a SoftReboot on the OLT.
    [Arguments]    ${bbsim_pod}    ${of_id}    ${olt_serial_number}   ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify UNI Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        Run Keyword If    "${workflow}"=="ATT"
        ...    Run Keywords
        # Verify ONU in AAA-Users (valid only for ATT)
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        ...    AND    List ONUs    ${NAMESPACE}    ${bbsim_pod}
        # Restart Auth and Verify (valid only for ATT)
        ...    AND    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    aaa-reset-all-devices
        ...    AND    Restart Auth    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        ...    AND    List ONUs    ${NAMESPACE}    ${bbsim_pod}
        # Add Subscriber
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify that no pending flows exist for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber  dhcp allocations (valid only for ATT and TT)
        Run Keyword If    "${workflow}"=="ATT" or "${workflow}"=="TT"
        ...    Run Keywords
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        ...    AND    List ONUs    ${NAMESPACE}    ${bbsim_pod}
        # Restart Dhcp and Verify (valid only for ATT and TT)
        ...    AND    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    dhcpl2relay-remove-allocation ${of_id} ${onu_port}
        ...    AND    Restart DHCP    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        ...    AND    List ONUs    ${NAMESPACE}    ${bbsim_pod}
        # Perform Igmp Join and Leave (valid only for TT)
        Run Keyword If    "${workflow}"=="TT"
        ...    Perform ONU Igmp Join and Leave    ${bbsim_pod}    ${of_id}    ${src['onu']}    ${onu_port}
    END
    # Clean ONOS state before rebooting
    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  aaa-reset-all-devices
    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  dhcpl2relay-clear-allocations
    # Perform OLT SoftReboot test
    ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
    Reboot Device    ${olt_device_id}
    Wait Until Keyword Succeeds    120s    2s    Device Is Available In ONOS
    ...    http://karaf:karaf@${ONOS_REST_IP}:${ONOS_REST_PORT}    ${of_id}     false
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    360s    5s
    ...    Validate OLT Device    ENABLED    ACTIVE
    ...    REACHABLE    ${olt_serial_number}
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    # Perform GRPC Disconnect test
    Restart Grpc Server    ${NAMESPACE}    ${bbsim_pod}    5
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
    # wait untill the device is connected again before proceeding
    Sleep   10


Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #send igmp file to onos (valid only for TT)
    ${onos_netcfg_file}=    Get Variable Value    ${onos_netcfg.file}
    Run Keyword If    '${workflow}'=='TT' and '${has_dataplane}'=='False' and '${onos_netcfg_file}'!='${None}'
    ...    Send File To Onos    ${onos_netcfg_file}    apps/

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    Close All ONOS SSH Connections
