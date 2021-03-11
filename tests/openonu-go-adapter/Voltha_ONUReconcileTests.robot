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
Documentation     Test different Reconcile scenarios of ONU Go adapter with all three workflows ATT, DT and TT.
...               Test suite is dedicated for only one ONU! Run robot with bbsim-kind.yaml only!
...               Not for DT/TT workflow!
...               Hint: default timeout in BBSim to mimic OLT reboot is 60 seconds!
...               This behaviour of BBSim can be modified by 'oltRebootDelay: 60' in BBSim section of helm chart or
...               used values.yaml during 'voltha up'.
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
# flag for first test, needed due default timeout in BBSim to mimic OLT reboot of 60 seconds
${firsttest}    True
# determines the environment workflow: DT, TT or ATT (default)
# example: -v workflow:DT
${workflow}    ATT
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
# if True (hard) kill will be used to restart onu adapter, else (soft) restart mechanism of k8s will be used
# example: -v usekill2restart:True
${usekill2restart}    False
${data_dir}    ../data
${suppressaddsubscriber}    True


*** Test Cases ***
Reconcile In Starting-OpenOmci
    [Documentation]    Validates the Reconcile in Starting-OpenOmci
    ...    Reconcile test during “starting-openomci” in AT&T-workflow:
    ...    - create and enable one BBSIM-ONU (no MIB-template should be available in KV-store)
    ...    - wait for device reason “starting-openomci”
    ...    - kill the open-onu-adapter-go
    ...    - wait for open-onu-adapter-go to restart
    ...    - perform sanity test include add subscriber
    ...    - delete ONU and MIB-template in KV-store
    [Tags]    functionalOnuGo    ReconcileStartingOpenOmciOnuGo
    [Setup]    Run Keywords    Start Logging    ReconcileStartingOpenOmciOnuGo
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Do Reconcile In Determined State    starting-openomci
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    ReconcileStartingOpenOmciOnuGo

Reconcile In Initial-Mib-Downloaded
    [Documentation]    Validates the Reconcile in initial-mib-downloaded
    ...    Reconcile test during “initial-mib-downloaded” in AT&T-workflow:
    ...    - create and enable one BBSIM-ONU (no MIB-template should be available in KV-store)
    ...    - wait for device reason “initial-mib-downloaded”
    ...    - kill the open-onu-adapter-go
    ...    - wait for open-onu-adapter-go to restart
    ...    - perform sanity test include add subscriber
    ...    - delete ONU and MIB-template in KV-store
    [Tags]    functionalOnuGo    ReconcileInitialMibDownloadedOnuGo
    [Setup]    Run Keywords    Start Logging    ReconcileInitialMibDownloadedOnuGo
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Do Reconcile In Determined State    initial-mib-downloaded
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    ReconcileInitialMibDownloadedOnuGo

Reconcile In Omci-Flows-Pushed
    [Documentation]    Validates the Reconcile in omci-flows-pushed
    ...    Former testcase: Reconcile Onu Device in Testsuite Voltha_ONUStateTest.robot
    ...    Reconcile test during “omci-flows-pushed” in AT&T-workflow:
    ...    - create and enable one BBSIM-ONU (no MIB-template should be available in KV-store)
    ...    - perform sanity test include add subscriber
    ...    - kill the open-onu-adapter-go
    ...    - wait for open-onu-adapter-go to restart
    ...    - perform sanity test suppress add subscriber
    ...    - disable onu device
    ...    - wait for device corresponding onu reason e.g. “tech-profile-config-delete-success”
    ...    - check UNI-ports disabled in ONOS
    ...    - enable onu device
    ...    - perform sanity test suppress add subscriber
    ...    - delete ONU and MIB-template in KV-store
    [Tags]    functionalOnuGo    ReconcileOmciFlowsPushedOnuGo
    [Setup]    Run Keywords    Start Logging    ReconcileOmciFlowsPushedOnuGo
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Do Reconcile In Omci-Flows-Pushed
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    ReconcileOmciFlowsPushedOnuGo

Reconcile For Disabled Onu Device
    [Documentation]    Validates the Reconcile for disabled Onu device
    ...    Reconcile test for disabled Onu device in AT&T-workflow:
    ...    - create and enable one BBSIM-ONU (no MIB-template should be available in KV-store)
    ...    - perform sanity test include add subscriber
    ...    - disable onu device
    ...    - wait for device corresponding onu reason e.g. “tech-profile-config-delete-success”
    ...    - check UNI-ports disabled in ONOS
    ...    - kill the open-onu-adapter-go
    ...    - wait for open-onu-adapter-go to restart
    ...    - check device reason is still the same before restart
    ...    - enable onu device
    ...    - perform sanity test suppress add subscriber
    ...    - delete ONU and MIB-template in KV-store
    [Tags]    functionalOnuGo    ReconcileDisabledOnuDeviceOnuGo
    [Setup]    Run Keywords    Start Logging    ReconcileDisabledOnuDeviceOnuGo
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Do Reconcile For Disabled Onu Device
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    ReconcileDisabledOnuDeviceOnuGo

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    ...    print2console:${print2console}, usekill2restart:${usekill2restart}, workflow:${workflow}
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
    Run Keyword If    ${usekill2restart}    Restart Pod    ${namespace}    open-onu
    Validate Onu Data In Etcd    0    without_pm_data=False
    Wait for Ports in ONOS for all OLTs      ${onos_ssh_connection}  0   BBSM    ${timeout}
    Close All ONOS SSH Connections

Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
    Run Keyword If    ${has_dataplane}    Sleep    60s
    #restart open-onu pod to reset crash loop back off mechansim of kubenetes
    Run Keyword If    "${firsttest}"=="False" and "${usekill2restart}"=="True"    Restart Pod    ${namespace}    open-onu
    Run Keyword If    "${firsttest}"=="False"    Sleep    35s
    ${firsttest}    Set Variable    False
    Set Suite Variable    ${firsttest}
    # Create a list of olt ids (logical and device_id)
    ${olt_ids}    Create List
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #create/preprovision device
        ${olt_device_id}=    Run Keyword If    "${list_olts}[${I}][type]" == "${None}"
        ...    Create Device    ${list_olts}[${I}][ip]    ${list_olts}[${I}][oltport]
        ...    ELSE    Create Device    ${list_olts}[${I}][ip]    ${list_olts}[${I}][oltport]    ${list_olts}[${I}][type]
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}
        Sleep    5s
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        ${olt}    Create Dictionary    device_id    ${olt_device_id}    logical_id    ${logical_id}
        ...    of_id    ${of_id}    sn    ${olt_serial_number}
        Append To List    ${olt_ids}    ${olt}
    END
    Set Global Variable    ${olt_ids}

Teardown Test
    [Documentation]    Post-test Teardown
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    # delete etcd MIB Template Data
    Delete MIB Template Data
    # check etcd data are empty
    Validate Onu Data In Etcd    0    without_pm_data=False
    Sleep    5s

Do Reconcile In Determined State
    [Documentation]    This keyword reconciles ONU device when passed reason is reached and
    ...    check the state afterwards.
    ...    Following steps will be executed:
    ...    - enable OLT device
    ...    - wait for passed openonu reason
    ...    - restart openonu adaptor
    ...    - perform sanity test include add subscriber
    [Arguments]    ${expected_onu_reason}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=    Map State
    ...    ${expected_onu_reason}
    Should Be True    ${onu_state_nb}<=5
    ...    Wrong expected onu reason ${expected_onu_reason}, must be lower than 'omci-flows-pushed'!
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    Current State Test All Onus    ${expected_onu_reason}
    Run Keyword If    ${usekill2restart}    Kill And Check Onu Adaptor    ${namespace}
    ...    ELSE    Restart And Check Onu Adaptor    ${namespace}
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test

Do Reconcile For Disabled Onu Device
    [Documentation]    This keyword reconciles ONU device for a disabled onu device and
    ...    check the state afterwards.
    ...    Following steps will be executed:
    ...    - enable OLT device
    ...    - perform sanity test include add subscriber
    ...    - disable onu device
    ...    - wait for corresponding openonu reason
    ...    - check UNI-ports disabled in ONOS
    ...    - restart openonu adaptor
    ...    - check openonu adaptor is ready again
    ...    - check device reason is still before restart
    ...    - enable onu device
    ...    - perform sanity test suppress add subscriber
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    Disable Onu Device
    ${alternativeonustates}=  Create List     omci-flows-deleted
    Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE       Current State Test All Onus    omci-admin-lock    alternativeonustate=${alternativeonustates}
    Run Keyword If    ${usekill2restart}    Kill And Check Onu Adaptor    ${namespace}
    ...    ELSE    Restart And Check Onu Adaptor    ${namespace}
    Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE       Current State Test All Onus    omci-admin-lock    alternativeonustate=${alternativeonustates}
    Wait for all ONU Ports in ONOS Disabled    ${onos_ssh_connection}
    Enable Onu Device
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}

Do Reconcile In Omci-Flows-Pushed
    [Documentation]    This keyword reconciles ONU device in omci-flows-pushed and check the state afterwards.
    ...    Reconcile test during “omci-flows-pushed” in AT&T-workflow:
    ...    - create and enable one BBSIM-ONU (no MIB-template should be available in KV-store)
    ...    - perform sanity test include add subscriber
    ...    - kill the open-onu-adapter-go
    ...    - wait for open-onu-adapter-go to restart
    ...    - perform sanity test suppress add subscriber
    ...    - disable onu device
    ...    - wait for corresponding device reason
    ...    - check UNI-ports disabled in ONOS
    ...    - enable onu device
    ...    - perform sanity test supress add subscriber
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    Run Keyword If    ${usekill2restart}    Kill And Check Onu Adaptor    ${namespace}
    ...    ELSE    Restart And Check Onu Adaptor    ${namespace}
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
    Disable Onu Device
    ${alternativeonustates}=  Create List     omci-flows-deleted
    Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE       Current State Test All Onus    omci-admin-lock    alternativeonustate=${alternativeonustates}
    Wait for all ONU Ports in ONOS Disabled    ${onos_ssh_connection}
    Enable Onu Device
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
