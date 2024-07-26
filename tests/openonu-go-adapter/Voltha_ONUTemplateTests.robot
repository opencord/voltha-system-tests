# Copyright 2020-2024 Open Networking Foundation Contributors
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
# Log Level of Helm chart
# example: -v helmloglevel:WARN
${helmloglevel}    DEBUG
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
    ...    AND    Stop Logging    UnknownAttributeOnuGo


ONU MIB Template Data Compare OMCI Baseline and Extended Message
    [Documentation]    Compares ONU Go adapter storage of MIB Template Data in etcd according OMCI message format
    ...                - setup one ONU with baseline OMCI message (EXTRA_HELM_FLAGS=" --set omccVersion=163)
    ...                - request MIB-Upload-Data by ONU via OMCI
    ...                - storage MIB-Upload-Data in etcd
    ...                - store setup duration of ONU
    ...                - check Template-Data in etcd stored (service/%{NAME}/omci_mibs/go_templates/)
    ...                - store Template-Data
    ...                - delete all devices and etcd/mib data
    ...                - setup one ONU with extended OMCI message (EXTRA_HELM_FLAGS=" --set omccVersion=180)
    ...                - request MIB-Upload-Data by ONU via OMCI
    ...                - storage MIB-Upload-Data in etcd
    ...                - store setup duration of ONU
    ...                - check Template-Data in etcd stored (service/%{NAME}/omci_mibs/go_templates/)
    ...                - compare both duration
    ...                - duration of extended msg ONU should be at least less than 80% of the baseline one
    ...                - compare MIB-Data, should be the same
    ...                ================= !!! Attention!!! ======================
    ...                    Should be always the last test case in test suite!
    ...                It changes BBSIM configuration to OMCI extended messages.
    ...                ================= !!! Attention!!! ======================
    [Tags]    functionalOnuGo    MibTemplateOmciBaselineVersusExtendedOnuGo
    [Setup]   Start Logging    MibTemplateOmciBaselineVersusExtendedOnuGo
    Perform ONU MIB Template Compare OMCI Baseline and Extended Message
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    MibTemplateOmciBaselineVersusExtendedOnuGo

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
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    # Start first Onu
    ${src}=    Set Variable    ${hosts.src[${0}]}
    Log    \r\nONU ${src['onu']}: startup with MIB upload cycle and storage of template data to etcd.    console=yes
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
    ${timeStart}=    Get Current Date
    ${firstonustartup}=    Get ONU Startup Duration    ${state2test}    ${firstonu}    ${timeStart}
    # check MIB Template data stored in etcd
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Verify MIB Template Data Available    ${INFRA_NAMESPACE}
    # Start second Onu
    ${src}=    Set Variable    ${hosts.src[${1}]}
    Log    ONU ${src['onu']}: startup without MIB upload cycle by using of template data of etcd.    console=yes
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
    ${timeStart}=    Get Current Date
    ${secondonustartup}=    Get ONU Startup Duration    ${state2test}    ${secondonu}    ${timeStart}
    # compare both durations, second onu should be at least 3 times faster
    ${status}    Evaluate    ${firstonustartup}>=${secondonustartup}*3
    Should Be True    ${status}
    ...    Startup durations (${firstonustartup} and ${secondonustartup}) do not full fill the requirements of 1/10.

Perform ONU MIB Template Compare OMCI Baseline and Extended Message
    [Documentation]    This keyword performs ONU MIB Template Data Compare OMCI Baseline and Extended Message
    ${firstonu}=      Set Variable    0
    ${waittime}=      Set Variable    0ms
    ${state2test}=    Set Variable    initial-mib-downloaded
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    ${omcc_version}    ${is_omcc_extended}=    Get BBSIM OMCC Version    ${NAMESPACE}
    # Restart BBSIM with OMCI Baseline Message if needed
    ${extra_helm_flags}    Catenate
    ...    --set onu=2,pon=2,controlledActivation=only-onu,injectOmciUnknownAttributes=true,injectOmciUnknownMe=true
    ...    --set omccVersion=163
    Run Keyword If    ${is_omcc_extended}    Restart BBSIM by Helm Charts    ${NAMESPACE}    extra_helm_flags=${extra_helm_flags}
    Setup
    ${src}=    Set Variable    ${hosts.src[${firstonu}]}
    Log    \r\nONU ${src['onu']}: startup with MIB upload cycle and storage of template data to etcd.    console=yes
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
    ${timeStart}=    Get Current Date
    ${baselineonustartup}=    Get ONU Startup Duration    ${state2test}    ${firstonu}    ${timeStart}    ${waittime}
    # check MIB Template data stored in etcd
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Verify MIB Template Data Available    ${INFRA_NAMESPACE}
    ${MibTemplateDataBaseline}=    Get ONU MIB Template Data    ${INFRA_NAMESPACE}
    # get ONU OMCI counter statistics
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${rc}    ${OMCI_counter_dict}=    Get OMCI counter statistics dictionary   ${onu_device_id}
    Run Keyword If    ${rc} != 0    FAIL    Could not get baseline ONU OMCI counter statistic of ONU ${src['onu']}!
    ${BaseTxArFrames}=    Get From Dictionary    ${OMCI_counter_dict}     BaseTxArFrames
    ${BaseRxAkFrames}=    Get From Dictionary    ${OMCI_counter_dict}     BaseRxAkFrames
    Should Be Equal As Integers   ${BaseTxArFrames}   ${BaseRxAkFrames}   Number of baseline Rx and Tx frames do not match!
    # some additional checks
    ${ExtRxAkFrames}=           Get From Dictionary   ${OMCI_counter_dict}   ExtRxAkFrames
    ${ExtRxNoAkFrames}=         Get From Dictionary   ${OMCI_counter_dict}   ExtRxNoAkFrames
    ${ExtTxArFrames}=           Get From Dictionary   ${OMCI_counter_dict}   ExtTxArFrames
    ${ExtTxNoArFrames}=         Get From Dictionary   ${OMCI_counter_dict}   ExtTxNoArFrames
    ${TxOmciCounterRetries}=    Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterRetries
    ${TxOmciCounterTimeouts}=   Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterTimeouts
    Should Be Equal   0   ${ExtRxAkFrames}          ExtRxAkFrames found in baseline OMCI!
    Should Be Equal   0   ${ExtRxNoAkFrames}        ExtRxNoAkFrames found in baseline OMCI!
    Should Be Equal   0   ${ExtTxArFrames}          ExtTxArFrames found in baseline OMCI!
    Should Be Equal   0   ${ExtTxNoArFrames}        ExtTxNoArFrames found in baseline OMCI!
    Should Be Equal   0   ${TxOmciCounterRetries}   TxOmciCounterRetries found in baseline OMCI!
    Should Be Equal   0   ${TxOmciCounterTimeouts}  TxOmciCounterTimeouts found in baseline OMCI!
    Delete All Devices and Verify
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # Restart BBSIM with OMCI Extended Message
    ${extra_helm_flags}    Catenate
    ...    --set onu=2,pon=2,controlledActivation=only-onu,injectOmciUnknownAttributes=true,injectOmciUnknownMe=true
    ${extra_helm_flags}=    Run Keyword If    ${is_omcc_extended}
    ...              Catenate    ${extra_helm_flags} --set omccVersion=${omcc_version}
    ...     ELSE     Catenate    ${extra_helm_flags} --set omccVersion=180
    Restart BBSIM by Helm Charts    ${NAMESPACE}    extra_helm_flags=${extra_helm_flags}
    # Start Onu again with OMCI Extended Message
    Setup
    ${src}=    Set Variable    ${hosts.src[${firstonu}]}
    Log    \r\nONU ${src['onu']}: startup with MIB upload cycle and storage of template data to etcd.    console=yes
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src['onu']}
    ${timeStart}=    Get Current Date
    ${extendedonustartup}=    Get ONU Startup Duration    ${state2test}    ${firstonu}    ${timeStart}    ${waittime}
    # check MIB Template data stored in etcd
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Verify MIB Template Data Available    ${INFRA_NAMESPACE}
    ${MibTemplateDataExtended}=    Get ONU MIB Template Data    ${INFRA_NAMESPACE}
    # Checks:
    # - compare durations of MIB download, OMCI extended message duration should be less than %60 of baseline
    # - both stored MIB tenmplates in ETCD should be equal
    ${duration_compare}=    Evaluate    ${baselineonustartup}*0.8 > ${extendedonustartup}
    Should Be True    ${duration_compare}   MIB Template download too slow for OMCI extended message!
    # remove "TemplateCreated"  e.g. "TemplateCreated":"2022-06-15 11:23:47.306519",
    ${remove_regexp}    Set Variable    (?ms)"TemplateCreated":"[^"]*",
    ${MibTemplateDataBaseline}=    Remove String Using Regexp    ${MibTemplateDataBaseline}    ${remove_regexp}
    ${MibTemplateDataExtended}=    Remove String Using Regexp    ${MibTemplateDataExtended}    ${remove_regexp}
    # Due to VOL-4721 comparison of MIB templates has to be executed without unknown ME!
    # After correction of Jira remove the following lines and this comment
    ${remove_regexp}    Set Variable    (?ms)"UnknownItuG988ManagedEntity":[^}]*}}}
    ${MibTemplateDataBaseline}=    Remove String Using Regexp    ${MibTemplateDataBaseline}    ${remove_regexp}
    ${MibTemplateDataExtended}=    Remove String Using Regexp    ${MibTemplateDataExtended}    ${remove_regexp}
    # end of handling for VOL-4721
    Should Be Equal As Strings    ${MibTemplateDataBaseline}    ${MibTemplateDataExtended}    MIB Templates not equal!
    # get ONU OMCI counter statistics
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${rc}    ${OMCI_counter_dict}=    Get OMCI counter statistics dictionary   ${onu_device_id}
    Run Keyword If    ${rc} != 0    FAIL    Could not get extended ONU OMCI counter statistic of ONU ${src['onu']}!
    ${ExtTxArFrames}=    Get From Dictionary    ${OMCI_counter_dict}    ExtTxArFrames
    ${ExtRxAkFrames}=    Get From Dictionary    ${OMCI_counter_dict}    ExtRxAkFrames
    Should Be Equal As Integers   ${ExtTxArFrames}   ${ExtRxAkFrames}   Number of extended Rx and Tx frames do not match!
    # check baseline and extended OMCI frames counter
    ${TxArFrames_compare}=    Evaluate    ${BaseTxArFrames}*0.05 > ${ExtTxArFrames}
    Should Be True    ${TxArFrames_compare}   Comparison of TxArFrames failed (${BaseTxArFrames}:${ExtTxArFrames})!
    ${RxAkFrames_compare}=    Evaluate    ${BaseRxAkFrames}*0.05 > ${ExtRxAkFrames}
    Should Be True    ${RxAkFrames_compare}   Comparison of RxAkFrames failed (${BaseRxAkFrames}:${ExtRxAkFrames})!
    # some additional checks
    ${TxOmciCounterRetries}=    Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterRetries
    ${TxOmciCounterTimeouts}=   Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterTimeouts
    Should Be Equal   0   ${TxOmciCounterRetries}   TxOmciCounterRetries found in extended OMCI!
    Should Be Equal   0   ${TxOmciCounterTimeouts}  TxOmciCounterTimeouts found in extended OMCI!
    # Restart BBSIM with OMCI Message Version read at begin of test
    ${extra_helm_flags}=    Catenate
    ...    --set onu=2,pon=2,controlledActivation=only-onu,injectOmciUnknownAttributes=true,injectOmciUnknownMe=true
    ...    --set omccVersion=${omcc_version}
    Run Keyword Unless   ${is_omcc_extended}   Restart BBSIM by Helm Charts   ${NAMESPACE}   extra_helm_flags=${extra_helm_flags}

Get ONU Startup Duration
    [Documentation]    This keyword delivers startup duration of onu
    [Arguments]    ${state2test}    ${onu}    ${starttime}    ${waittime}=50ms
    ${src}=    Set Variable    ${hosts.src[${onu}]}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    ${state2test}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    ${waittime}
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
