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

*** Settings ***
Documentation     Negative test states of ONU Go adapter with ATT workflows only (not for DT/TT workflow!)
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
${NAMESPACE}      voltha
${INFRA_NAMESPACE}      default
${timeout}        300s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    True
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}
# KV Store Prefix
# example: -v kvstoreprefix:voltha_voltha
${kvstoreprefix}    voltha_voltha
# used tech profile, can be passed via the command line too, valid values: default (=1T1GEM), 1T4GEM, 1T8GEM
# example: -v techprofile:1T4GEM
${techprofile}    default
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
${data_dir}    ../data


*** Test Cases ***
ONU Negative State Test
    [Documentation]    Validates the ONU Go adapter states will never leave starting-openomci
    ...                Due to a 'omci-response-rate' lower than 8 more OMCI messages will be through away by BBSIM than
    ...                repeated by openonu-go-adapter. So ONU will never leave starting-openomci state.
    ...                Timeout has to set at least to 300s (or more)
    [Tags]    NegativeStateTestOnuGo
    [Setup]    Run Keywords    Start Logging    ONUNegativeStateTest
    ...    AND    Setup
    # Suite Variable will be overwritten by Teardown of Current State Test All Onus
    Set Suite Variable    ${StateTestAllONUs}    True
    ${seconds}=    Convert Time    ${timeout}
    ${seconds}=    Convert To String    ${seconds}
    ${seconds}=    Get Substring    ${seconds}    0    -2
    FOR    ${I}    IN RANGE    ${seconds}
        Sleep    1s
        Current State Test All Onus    starting-openomci    timeout=1x
        Exit For Loop If    not ${StateTestAllONUs}
    END
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUStateTest


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    techprofile:${techprofile},
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    ...    print2console:${print2console}
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    ${techprofile}=    Set Variable If    "${techprofile}"=="1T1GEM"    default    ${techprofile}
    Set Suite Variable    ${techprofile}
    Run Keyword If    "${techprofile}"=="default"   Log To Console    \nTechProfile:default (1T1GEM)
    ...    ELSE IF    "${techprofile}"=="1T4GEM"    Set Tech Profile    1T4GEM    ${INFRA_NAMESPACE}
    ...    ELSE IF    "${techprofile}"=="1T8GEM"    Set Tech Profile    1T8GEM    ${INFRA_NAMESPACE}
    ...    ELSE    Fail    The TechProfile (${techprofile}) is not valid!
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # delete etcd onu data
    Delete ONU Go Adapter ETCD Data    namespace=${INFRA_NAMESPACE}    validate=True

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    ...    Furthermore gives the possibility to pause the execution.
    Start Logging Setup or Teardown   Teardown-${SUITE NAME}
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    Wait Until Keyword Succeeds    ${timeout}    1s    Validate Onu Data In Etcd    ${INFRA_NAMESPACE}    0    ${kvstoreprefix}
    ...    without_pm_data=False
    Wait for Ports in ONOS for all OLTs      ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  0   BBSM    ${timeout}
    Run Keyword If    ${logging}    Collect Logs
    Stop Logging Setup or Teardown   Teardown-${SUITE NAME}
    Close All ONOS SSH Connections
    Remove Tech Profile    ${INFRA_NAMESPACE}
