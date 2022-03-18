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
Documentation     Test MIB Template handling of ONU Go adapter
...               with BBSIM controlledActivation: only-onu only!
...               Set up BBSIM with 'onu=2' (as well as 'pon=2') and 'controlledActivation=only-onu' e.g. with Extra Helm Flags!
...               Run robot with bbsim-kind-2x2.yaml (needed for test case ONU MIB Template Data Test)
...               For test cases Unknown ME/Attribute bbsim-kind.yaml would work too.
...               For Unknown ME set up BBSIM with injectOmciUnknownME=true e.g. with Extra Helm Flags!
...               For Unknown Attribute set up BBSIM with injectOmciUnknownAttributes=true e.g. with Extra Helm Flags!
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
Resource          ../../libraries/bbsim.robot
Resource          ../../variables/variables.robot

*** Variables ***
${NAMESPACE}          voltha
${INFRA_NAMESPACE}    default
${timeout}            60s
${of_id}              0
${logical_id}         0
${has_dataplane}      True
${external_libs}      True
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

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

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
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    ONUMibTemplateTest

ONU MIB Template Unknown ME Test
    [Documentation]    Validates ONU Go adapter storage of MIB Template Data in etcd in case of unknown ME
    ...                - setup one ONU
    ...                - request MIB-Upload-Data by ONU via OMCI
    ...                - storage MIB-Upload-Data in etcd
    ...                - check Template-Data in etcd stored (service/voltha/omci_mibs/go_templates/)
    ...                - Template-Data in etcd stored should contain "UnknownItuG988ManagedEntity"
    [Tags]    functionalOnuGo    UnknownMeOnuGo
    [Setup]    Run Keywords    Start Logging    UnknownMeOnuGo
    ...    AND    Setup
    Bring Up ONU
    ${MibTemplateData}=    Get ONU MIB Template Data    ${INFRA_NAMESPACE}
    ${MibTemplatePrep}=    Prepare ONU Go Adapter ETCD Data For Json    ${MibTemplateData}
    ${MibTemplateJson}=    To Json    ${MibTemplatePrep}
    Dictionary Should Contain Key    ${MibTemplateJson[0]}    UnknownItuG988ManagedEntity
    ${UnknownME}=    Get From Dictionary    ${MibTemplateJson[0]}    UnknownItuG988ManagedEntity
    Dictionary Should Contain Key    ${UnknownME}    37
    ${Attributes}=    Get From Dictionary    ${UnknownME['37']}    1
    ${AttributeMask}=     Get From Dictionary    ${Attributes}    AttributeMask
    ${AttributeBytes}=    Get From Dictionary    ${Attributes}    AttributeBytes
	Should be Equal     ${AttributeMask}     0x8000
	Should be Equal     ${AttributeBytes}    0102030405060708090a0b0c0d0e0f101112131415161718191a
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    UnknownMeOnuGo

ONU MIB Template Unknown Attribute Test
    [Documentation]    Validates ONU Go adapter storage of MIB Template Data in etcd in case of unknown Attribute
    ...                - setup one ONU
    ...                - request MIB-Upload-Data by ONU via OMCI
    ...                - storage MIB-Upload-Data in etcd
    ...                - check Template-Data in etcd stored (service/voltha/omci_mibs/go_templates/)
    ...                - Template-Data in etcd stored should contain "UnknownAttributesManagedEntity"
    [Tags]    functionalOnuGo    UnknownAttributeOnuGo
    [Setup]    Run Keywords    Start Logging    UnknownAttributeOnuGo
    ...    AND    Setup
    Bring Up ONU
    ${MibTemplateData}=    Get ONU MIB Template Data    ${INFRA_NAMESPACE}
    ${MibTemplatePrep}=    Prepare ONU Go Adapter ETCD Data For Json    ${MibTemplateData}
    ${MibTemplateJson}=    To Json    ${MibTemplatePrep}
    Dictionary Should Contain Key    ${MibTemplateJson[0]}    UnknownAttributesManagedEntity
    ${UnknownME}=    Get From Dictionary    ${MibTemplateJson[0]}    UnknownAttributesManagedEntity
    Dictionary Should Contain Key    ${UnknownME}    257
    ${Attributes}=    Get From Dictionary    ${UnknownME['257']}    0
    ${AttributeMask}=     Get From Dictionary    ${Attributes}    AttributeMask
    ${AttributeBytes}=    Get From Dictionary    ${Attributes}    AttributeBytes
	Should be Equal     ${AttributeMask}     0x0001
	Should be Equal     ${AttributeBytes}    000100010001000000
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    UnknownMeOnuGo

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Start Logging Setup or Teardown    Setup-${SUITE NAME}
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    Run Keyword If    ${logging}    Collect Logs
    Stop Logging Setup or Teardown    Setup-${SUITE NAME}

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    ...    Furthermore gives the possibility to pause the execution.
    Start Logging Setup or Teardown   Teardown-${SUITE NAME}
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    Wait for Ports in ONOS for all OLTs      ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  0   BBSM
    # delete etcd MIB Template Data (for repeating test)
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    Run Keyword If    ${logging}    Collect Logs
    Stop Logging Setup or Teardown   Teardown-${SUITE NAME}
    Close All ONOS SSH Connections

Teardown Test
    [Documentation]    Post-test Teardown
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    Sleep    5s

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
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
    ${timeStart}=    Get Current Date
    ${firstonustartup}=    Get ONU Startup Duration    ${firstonu}    ${timeStart}
    # check MIB Template data stored in etcd
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Verify MIB Template Data Available    ${INFRA_NAMESPACE}
    # Start second Onu
    ${src}=    Set Variable    ${hosts.src[${1}]}
    Log    ONU ${src['onu']}: startup without MIB upload cycle by using of template data of etcd.    console=yes
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
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

Bring Up ONU
    [Documentation]    This keyword brings up onu
    [Arguments]    ${onu}=0    ${state2reach}=omci-flows-pushed
    ${src}=    Set Variable    ${hosts.src[${onu}]}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    ${state2reach}
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${src['onu']}    onu=True    onu_reason=${onu_state}
