# Copyright 2020 - present Open Networking Foundation
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
Documentation     Test Template handling of ONU Go adapter with BBSIM controlledActivation: only-onu only!
...               Values.yaml must contain 'onu: 2' and 'controlledActivation: only-onu' under BBSIM!
...               Run robot with bbsim-kind-2x2.yaml
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
Resource          ../../libraries/onu_utilities.robot
Resource          ../../variables/variables.robot

*** Variables ***
${namespace}      voltha
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    True
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# flag debugmode is used, if true timeout calculation various, can be passed via the command line too
# example: -v debugmode:True
${debugmode}    False
# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
# if True execution will be paused before clean up
# example: -v pausebeforecleanup:True
${pausebeforecleanup}    False
${data_dir}    ../data


*** Test Cases ***
ONU MIB Template Data Test
    [Documentation]    Validates ONU Go adapter storage of MIB Template Data in etcd and checks the usage
    ...                - setup one ONU
    ...                - request MIB-Upload-Data by ONU via OMCI
    ...                - storage MIB-Upload-Data in etcd
    ...                - store setup duration of ONU
    ...                - check Template-Data in etcd stored (service/%{NAME}/omci_mibs/go_templates/)
    ...                - setup second ONU
    ...                - collect setup durationof second ONU
    ...                - compare both duration
    ...                - duration of second ONU should be at least 10 times faster than the first one
    ...                - MIB-Upload-Data should not requested via OMCI by second ONU
    ...                - MIB-Upload-Data should read from etcd
    [Tags]    functionalOnuGo    MibTemplateOnuGo
    [Setup]    Run Keywords    Start Logging    ONUMibTemplateTest
    ...    AND    Setup
    Perform ONU MIB Template Data Test
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUMibTemplateTest


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable  ${onos_ssh_connection}
    # delete etcd MIB Template Data
    Delete MIB Template Data

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    ...    Furthermore gives the possibility to pause the execution.
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    Wait for Ports in ONOS for all OLTs      ${onos_ssh_connection}  0   BBSM
    # delete etcd MIB Template Data (for repeating test)
    Delete MIB Template Data
    Close All ONOS SSH Connections

Perform ONU MIB Template Data Test
    [Documentation]    This keyword performs ONU MIB Template Data Test
    ${firstonu}=      Set Variable    0
    ${secondonu}=     Set Variable    1
    ${state2test}=    Set Variable    omci-flows-pushed
    Set Global Variable    ${state2test}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    # Start first Onu
    ${src}=    Set Variable    ${hosts.src[${0}]}
    Log    \r\nONU ${src['onu']}: startup with MIB upload cycle and storage of template data to etcd.    console=yes
    ${result}=    Exec Pod In Kube    ${namespace}    bbsim    bbsimctl onu poweron ${src['onu']}
    Should Contain    ${result}    successfully    msg=Can not poweron ${src['onu']}    values=False
    ${timeStart}=    Get Current Date
    ${firstonustartup}=    Get ONU Startup Duration    ${firstonu}    ${timeStart}
    # check MIB Template data stored in etcd
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Verify MIB Template Data Available
    # Start second Onu
    ${src}=    Set Variable    ${hosts.src[${1}]}
    Log    ONU ${src['onu']}: startup without MIB upload cycle by using of template data of etcd.    console=yes
    ${result}=    Exec Pod In Kube    ${namespace}    bbsim    bbsimctl onu poweron ${src['onu']}
    Should Contain    ${result}    successfully    msg=Can not poweron ${src['onu']}    values=False
    ${timeStart}=    Get Current Date
    ${secondonustartup}=    Get ONU Startup Duration    ${secondonu}    ${timeStart}
    # compare both durations, second onu should be at least 3 times faster
    ${status}    Evaluate    ${firstonustartup}>=${secondonustartup}*3
    Should Be True    ${status}
    ...    Startup durations (${firstonustartup} and ${secondonustartup}) do not full fill the requirements of 1/10.

Get ONU Startup Duration
    [Documentation]    This keyword delivers startup duration of onu
    [Arguments]    ${onu}    ${starttime}
    ${src}=    Set Variable    ${hosts.src[${onu}]}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    ${state2test}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${src['onu']}    onu=True    onu_reason=${onu_state}
    ${timeCurrent} =    Get Current Date
    ${timeTotalMs} =    Subtract Date From Date    ${timeCurrent}    ${startTime}    result_format=number
    Log    ONU ${src['onu']}: reached the state ${onu_state} after ${timeTotalMs} sec.    console=yes
    [Return]    ${timeTotalMs}
