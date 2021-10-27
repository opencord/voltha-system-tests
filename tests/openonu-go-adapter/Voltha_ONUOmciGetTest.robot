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
Documentation     Test of open ONU go adapter OMCI Get
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
${namespace}      voltha
${INFRA_NAMESPACE}      default
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    True
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}
# determines the environment workflow: DT, TT or ATT (default)
# example: -v workflow:DT
${workflow}    ATT
# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
${data_dir}    ../data

*** Test Cases ***
ANI-G Test
    [Documentation]    Validates ANI-G output of ONU device(s):
    [Tags]    functionalOnuGo    AniGTest
    [Setup]    Start Logging    AniGTest
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${voltctl_commad} =    Catenate    SEPARATOR=
        ...    voltctl device getextval onu_pon_optical_info ${onu_device_id}
        ${rc}    ${output}=    Run and Return Rc and Output    ${voltctl_commad}
        Should Be Equal As Integers    ${rc}    0
        Should Contain    ${output}    POWER_FEED_VOLTAGE__VOLTS:
        Should Contain    ${output}    3.26
        Should Contain    ${output}    RECEIVED_OPTICAL_POWER__dBm:
        Should Contain    ${output}    MEAN_OPTICAL_LAUNCH_POWER__dBm:
        Should Contain    ${output}    LASER_BIAS_CURRENT__mA:
        Should Contain    ${output}    TEMPERATURE__Celsius:
    END
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND    Stop Logging    SanityTestOnuGo

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite inclusive enable device and sanity test of given workflow
    Common Test Suite Setup
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
