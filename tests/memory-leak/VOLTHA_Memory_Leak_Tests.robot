# Copyright 2022 - present Open Networking Foundation
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
Documentation     Test of try to catch memory leak in voltha components.
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
${NAMESPACE}      voltha
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
# KV Store Prefix
# example: -v kvstoreprefix:voltha/voltha_voltha
${kvstoreprefix}    voltha/voltha_voltha
# flag debugmode is used, if true timeout calculation various, can be passed via the command line too
# example: -v debugmode:True
${debugmode}    False
# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
# if True execution will be paused before clean up, only use in case of manual testing, do not use in ci pipeline!
# example: -v pausebeforecleanup:True
${pausebeforecleanup}    False
# if True some outputs to console are done during running tests e.g. long duration flow test
# example: -v print2console:True
${print2console}    False
# if True etcd check will be executed in test case teardown, if False etcd check will be executed in suite teardown
# example: -v etcdcheckintestteardown:False
${etcdcheckintestteardown}    True
${data_dir}    ../data
# number of iterations
# example: -v iterations:10
${iterations}    200

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

*** Test Cases ***
Memory Leak Test Openonu Go Adapter
    [Documentation]   Test of try to catch memory leak in Openonu Go Adapter for all three workflows, ATT, DT and TT
    ...    Multiple run of Flow and ONU setup and teardown to try to catch memory leak.
    ...    - do workflow related sanity test (bring up onu to omci flows pushed and setup flows)
    ...    - remove flows
    ...    - delete ONU devices
    ...    - wait for onu auto detect
    [Tags]    functionalMemoryLeak    MemoryLeakTestOnuGo
    [Setup]    Run Keywords    Start Logging    MemoryLeakTestOnuGo
    ...        AND             Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${print2console}    Log    \r\nStart ${iterations} iterations.    console=yes
    FOR    ${I}    IN RANGE    1    ${iterations} + 1
        Run Keyword If    ${print2console}    Log    \r\nStart iteration ${I} of ${iterations}.    console=yes
        Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
        ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
        ...    ELSE       Perform Sanity Test
        Run Keyword If    ${print2console}    Log    Remove Flows.    console=yes
        Remove Flows all ONUs
        Run Keyword If    ${print2console}    Log    Check Flows removed.    console=yes
        Check All Flows Removed
        Run Keyword If    ${print2console}    Log    Get ONU Device IDs.    console=yes
        ${onu_device_id_list}=    Get ONUs Device IDs from Voltha
        Run Keyword If    ${print2console}    Log    Delete ONUs.    console=yes
        Delete Devices In Voltha    Type=brcm_openomci_onu
        Run Keyword If    ${print2console}    Log    Wait for ONUs come back.    console=yes
        Wait Until Keyword Succeeds    ${timeout}    1s  Check for new ONU Device IDs     ${onu_device_id_list}
        ${list_onus}    Create List
        Build ONU SN List    ${list_onus}
        Wait Until Keyword Succeeds    ${timeout}    1s  Check all ONU OperStatus     ${list_onus}  ACTIVE
        Run Keyword If    ${print2console}    Log    End iteration ${I} of ${iterations}.    console=yes
    END
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    MemoryLeakTestOnuGo

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Start Logging Setup or Teardown    Setup-${SUITE NAME}
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    ...    print2console:${print2console}, workflow:${workflow}, kvstoreprefix:${kvstoreprefix},
    ...    iterations:${iterations}
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    # set tech profiles
    ${preload_tech_profile}=   Set Variable If   ${unitag_sub} and "${workflow}"=="TT" and not ${has_dataplane}   True   False
    Set Suite Variable    ${preload_tech_profile}
    Run Keyword If   ${preload_tech_profile}   Set Tech Profile   TT-HSIA                                ${INFRA_NAMESPACE}    64
    Run Keyword If   ${preload_tech_profile}   Set Tech Profile   TT-VoIP                                ${INFRA_NAMESPACE}    65
    Run Keyword If   ${preload_tech_profile}   Set Tech Profile   TT-multi-uni-MCAST-AdditionalBW-None   ${INFRA_NAMESPACE}    66
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # delete etcd onu data
    Delete ONU Go Adapter ETCD Data    namespace=${INFRA_NAMESPACE}    validate=True
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
    Run Keyword Unless    ${etcdcheckintestteardown}    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Onu Data In Etcd    ${INFRA_NAMESPACE}    0    ${kvstoreprefix}    without_pm_data=False
    Wait for Ports in ONOS for all OLTs      ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  0   BBSM    ${timeout}
    Run Keyword If    ${logging}    Collect Logs
    Stop Logging Setup or Teardown   Teardown-${SUITE NAME}
    Close All ONOS SSH Connections
    Set Suite Variable    ${TechProfile}    ${EMPTY}
    Run Keyword If    ${preload_tech_profile}    Remove Tech Profile    ${INFRA_NAMESPACE}    64
    Run Keyword If    ${preload_tech_profile}    Remove Tech Profile    ${INFRA_NAMESPACE}    65
    Run Keyword If    ${preload_tech_profile}    Remove Tech Profile    ${INFRA_NAMESPACE}    66

Teardown Test
    [Documentation]    Post-test Teardown
    # log ONOS flows after remove check
    ${flow}=    Run Keyword If    "${TEST STATUS}"=="FAIL"    Execute ONOS CLI Command use single connection
    ...    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s any ${of_id}
    Run Keyword If    "${TEST STATUS}"=="FAIL"    Log    ${flow}
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}       Delete All Devices and Verify
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # check etcd data are empty
    Run Keyword If    ${etcdcheckintestteardown}    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Onu Data In Etcd    ${INFRA_NAMESPACE}    0    ${kvstoreprefix}    without_pm_data=False
    Sleep    5s

Check for new ONU Device IDs
    [Documentation]    Checks that no old onu device ids stays
    [Arguments]    ${old_device_ids}
    ${new_device_ids}=    Get ONUs Device IDs from Voltha
    Should Not Be Empty    ${new_device_ids}    No new ONU device IDs
    FOR    ${item}    IN    @{old_device_ids}
        List Should Not Contain Value    ${new_device_ids}    ${item}    Old device id ${item} still present.
    END
