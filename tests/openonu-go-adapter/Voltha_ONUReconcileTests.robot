# Copyright 2020-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
# flag for first test, needed due default timeout in BBSim to mimic OLT reboot of 60 seconds
${firsttest}    True
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
# if True (hard) kill will be used to restart onu adapter, else (soft) restart mechanism of k8s will be used
# example: -v usekill2restart:True
${usekill2restart}    False
# if True etcd check will be executed in test case teardown, if False etcd check will be executed in suite teardown
# example: -v etcdcheckintestteardown:False
${etcdcheckintestteardown}    True
${data_dir}    ../data
${suppressaddsubscriber}    True

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

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
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
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
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
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
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
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
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    ReconcileDisabledOnuDeviceOnuGo

Olt Deletion After Adapter Restart
    [Documentation]    Validates the OLT deletion after adapter restart
    ...    - prefered environment is two ONUs are active on each of two OLTs, but test works also with single ONU/OLT
    ...    - restart the ONU adapter preferred via "kubectl delete pod"
    ...    - delete one OLT immediately after the restart has been initiated
    ...    - wait until the restart of the ONU adapter and the reconcile processing are finished
    ...    - check whether the ONUs on the remaining OLT have been properly reconciled (if avaialable)
    ...    - check whether the ONUs at the deleted OLT have disappeared from the device list
    ...    - KV store data of these ONUs are deleted under:
    ...        - <kvStorePrefix>/openonu/<deviceId>
    ...        - <kvStorePrefix>/openonu/pm-data/<deviceId>
    ...    - check for not deleted device(s) reason is still the same before restart (if available)
    ...    - delete ONU and MIB-template in KV-store
    ...    Check [VOL-4443] for more details
    [Tags]    functionalOnuGo    OltDeletionAfterAdapterRestartOnuGo
    [Setup]    Run Keywords    Start Logging    OltDeletionAfterAdapterRestartOnuGo
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Do Olt Deletion After Adapter Restart
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    OltDeletionAfterAdapterRestartOnuGo

Flow Deletion After Adapter Restart
    [Documentation]    Validates the flow(s) deletion after adapter restart
    ...    - perform sanity test include add subscriber
    ...    - restart the ONU adapter preferred via "kubectl delete pod"
    ...    - remove flow(s) from one ONU immediately after the restart has been initiated
    ...    - wait until the restart of the ONU adapter and the reconcile processing are finished
    ...    - check removed  flow(s) from ONU
    ...    - check for not removed flows still the same before restart (if available)
    [Tags]    functionalOnuGo    FlowDeletionAfterAdapterRestartOnuGo
    [Setup]    Run Keywords    Start Logging    FlowDeletionAfterAdapterRestartOnuGo
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Do Flow Deletion After Adapter Restart
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    FlowDeletionAfterAdapterRestartOnuGo

Wrong MDS Counter After Adapter Restart
    [Documentation]    Validates wrong MDS Counter of ONU after adapter restart
    ...    - perform sanity test include add subscriber
    ...    - restart the ONU adapter preferred via "kubectl delete pod"
    ...    - manipulate MDS counter
    ...    - wait until the restart of the ONU adapter and the reconcile processing are finished
    ...    - check all ONUs come up to previous state
    [Tags]    functionalOnuGo    WrongMDSCounterAfterAdapterRestartOnuGo
    [Setup]    Run Keywords    Start Logging    WrongMDSCounterAfterAdapterRestartOnuGo
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Do Wrong MDS Counter After Adapter Restart
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Stop Logging    WrongMDSCounterAfterAdapterRestartOnuGo

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Start Logging Setup or Teardown    Setup-${SUITE NAME}
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    ...    print2console:${print2console}, usekill2restart:${usekill2restart}, workflow:${workflow},
    ...    kvstoreprefix:${kvstoreprefix}
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
    Run Keyword If    ${usekill2restart}    Restart Pod By Label    ${NAMESPACE}    app    adapter-open-onu
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

Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
    Run Keyword If    ${has_dataplane}    Sleep    60s
    #restart open-onu pod to reset crash loop back off mechansim of kubenetes
    Run Keyword If    "${firsttest}"=="False" and "${usekill2restart}"=="True"
    ...    Restart Pod By Label    ${NAMESPACE}    app    adapter-open-onu
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
        ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}    by_dev_id=True
        Sleep    5s
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        ${olt}    Create Dictionary    device_id    ${olt_device_id}    logical_id    ${logical_id}
        ...    of_id    ${of_id}    sn    ${olt_serial_number}
        Append To List    ${olt_ids}    ${olt}
    END
    Set Global Variable    ${olt_ids}

Teardown Test
    [Documentation]    Post-test Teardown
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # check etcd data are empty
    Run Keyword If    ${etcdcheckintestteardown}    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Onu Data In Etcd    ${INFRA_NAMESPACE}    0    ${kvstoreprefix}    without_pm_data=False
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
    Reconcile Onu Adapter    ${NAMESPACE}    ${usekill2restart}    ACTIVE
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
    Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    tech-profile-config-delete-success
    ...    ELSE       Current State Test All Onus    tech-profile-config-delete-success
    #check no port is enabled in ONOS
    Wait for Ports in ONOS for all OLTs    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    0    BBSM
    Wait for all ONU Ports in ONOS Disabled    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${unitag_sub}
    # validate etcd data
    ${List_ONU_Serial}    Create List
    Build ONU SN List    ${List_ONU_Serial}
    ${must_exist}=    Set Variable If    "${workflow}"=="DT"    True    False
    ${check_empty}=   Set Variable If    "${workflow}"=="DT"    False   True
    FOR  ${onu_sn}  IN  @{List_ONU_Serial}
        Wait Until Keyword Succeeds    ${timeout}    2s    Validate Tech Profiles and Flows in ETCD Data Per Onu
        ...    ${onu_sn}   ${INFRA_NAMESPACE}   ${kvstoreprefix}  must_exist=${must_exist}   check_tcont_map_empty=${check_empty}
        ...    check_default_flow_att=False
    END
    Reconcile Onu Adapter    ${NAMESPACE}    ${usekill2restart}    UNKNOWN
    Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    tech-profile-config-delete-success
    ...    ELSE       Current State Test All Onus    tech-profile-config-delete-success
    Wait for all ONU Ports in ONOS Disabled    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${unitag_sub}
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
    Reconcile Onu Adapter    ${NAMESPACE}    ${usekill2restart}    ACTIVE
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
    Disable Onu Device
    Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    tech-profile-config-delete-success
    ...    ELSE       Current State Test All Onus    tech-profile-config-delete-success
    Wait for all ONU Ports in ONOS Disabled    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${unitag_sub}
    Enable Onu Device
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}


Do Olt Deletion After Adapter Restart
    [Documentation]    This keyword deletes OLT after adapter restart and checks deleted device(s) and data
    ...    - prefered environment is two ONUs are active on each of two OLTs, but test works also with single ONU/OLT
    ...    - restart the ONU adapter preferred via "kubectl delete pod"
    ...    - delete one OLT immediately after the restart has been initiated
    ...    - wait until the restart of the ONU adapter and the reconcile processing are finished
    ...    - check whether the ONUs on the remaining OLT have been properly reconciled (if avaialable)
    ...    - check whether the ONUs at the deleted OLT have disappeared from the device list
    ...    - KV store data of these ONUs are deleted under:
    ...        - <kvStorePrefix>/openonu/<deviceId>
    ...        - <kvStorePrefix>/openonu/pm-data/<deviceId>
    ...    - check for not deleted device(s) reason is still the same before restart (if available)
    ...    - delete ONU and MIB-template in KV-store
    ...    Check [VOL-4443] for more details
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    # bring all onus to active -> OMCI-Flows-Pushed
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    # OLT#1 will be deleted, get its SN
    ${olt_to_be_deleted}=    Set Variable    ${olts[0]['serial']}
    ${olt_to_be_deleted_device_id}=    Get OLTDeviceID From OLT List    ${olt_to_be_deleted}
    # collect all ONU device ids belonging to OLT to be deleted
    ${onu_device_id_list_should_be_deleted}    Create List
    Build ONU Device Id List    ${onu_device_id_list_should_be_deleted}    ${olt_to_be_deleted}
    Log    ${onu_device_id_list_should_be_deleted}
    Reconcile Onu Adapter    ${NAMESPACE}    ${usekill2restart}    ACTIVE    ${olt_to_be_deleted}
    # validate OLT and all corresponding ONUs are removed
    Validate all ONUS for OLT Removed    ${num_all_onus}    ${hosts}    ${olt_to_be_deleted}    ${timeout}
    Validate Device Removed    ${olt_to_be_deleted}
    # validate for alle removed ONUs KV store date deleted
    FOR  ${onu_device_id}  IN  @{onu_device_id_list_should_be_deleted}
        Log  ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    1s    Validate Onu Data In Etcd Removed    ${INFRA_NAMESPACE}
        ...    ${onu_device_id}    ${kvstoreprefix}    without_pm_data=False
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_to_be_deleted}"=="${src['olt']}"
        Current State Test    omci-flows-pushed    ${src['onu']}
    END

Do Flow Deletion After Adapter Restart
    [Documentation]    This keyword removes flow(s) after adapter restart and checks removed flow(s)
    ...    - perform sanity test include add subscriber
    ...    - restart the ONU adapter preferred via "kubectl delete pod"
    ...    - remove flow(s) from one ONU immediately after the restart has been initiated
    ...    - wait until the restart of the ONU adapter and the reconcile processing are finished
    ...    - check removed  flow(s) from ONU
    ...    - check for not removed flows still the same before restart (if available)
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    # bring all onus to active -> OMCI-Flows-Pushed
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    # log ONOS flows before remove
    ${flow}=    Execute ONOS CLI Command use single connection
    ...    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s any ${of_id}
    Log    ${flow}
    # validate OLT flows before  remove
    ${onu_device_id_list}    Create List
    Build ONU Device Id List    ${onu_device_id_list}
    Log    ${onu_device_id_list}
    FOR  ${onu_device_id}  IN  @{onu_device_id_list}
        Log  ${onu_device_id}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    voltctl -c ${VOLTCTL_CONFIG} device flows ${onu_device_id} -m 32MB -o json
        Should Be Equal As Integers    ${rc}    0
        ${jsondata}=    To Json    ${output}
        Log    ${jsondata}
    END
    # Collect data for remove flow(s)
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${hosts.src[0]['olt']}
    ${onu_sn}=    Set Variable   ${hosts.src[0]['onu']}
    ${onu_port_list}    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${onu_sn}"!="${src['onu']}"
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${port_id}=    Get Index From List    ${onu_port_list}   ${onu_port}
        Continue For Loop If    -1 != ${port_id}
        Append To List    ${onu_port_list}    ${onu_port}
    END
    ${params_for_remove_flow}=    Create Dictionary    unitag=${unitag_sub}    onu_sn=${onu_sn}    of_id=${of_id}
    ...    onu_port=${onu_port_list[0]}
    # Collect number of flows for comparing after Reconcile
    ${olt_flows_list}    Create List
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${olt_of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${list_olts}[${I}][sn]
        ${flows}=    Count flows    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${olt_of_id}   added
        ${olt_flows}=    Create Dictionary    olt=${olt_of_id}    flows=${flows}
        Append To List    ${olt_flows_list}    ${olt_flows}
    END
    ${flows_onu}=    Set Variable    0
    FOR  ${onu_port}  IN  @{onu_port_list}
        ${flows_onu_port}=    Count flows    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}   added    ${onu_port}
        ${flows_onu}=    Evaluate     ${flows_onu} + ${flows_onu_port}
    END
    # Restart onu adapter with deleting flows from first onu
    Reconcile Onu Adapter    ${NAMESPACE}    ${usekill2restart}    ACTIVE    flow_delete_params=${params_for_remove_flow}
    # validate flows in ONOS after remove
    ${flow}=    Execute ONOS CLI Command use single connection
    ...    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s any ${of_id}
    Log    ${flow}
    ${expected_flows_onu}=    Set Variable If   "${workflow}"=="ATT"    1    0
    FOR  ${onu_port}  IN  @{onu_port_list}
        Wait Until Keyword Succeeds    ${timeout}    2s    Validate number of flows    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${expected_flows_onu}  ${of_id}   any    ${onu_port}
    END
    ${flow}=    Execute ONOS CLI Command use single connection
    ...    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s any ${of_id}
    Log    ${flow}
    # Beside onu port specific flows additional flows deleted depending on workflow and number of onu ports
    ${number_ports}=    Get Length    ${onu_port_list}
    ${additional_flows_deleted}=    Run Keyword If    "${workflow}"=="DT"    Set Variable    ${number_ports}
    ...                             ELSE IF           "${workflow}"=="TT"    Evaluate        ${number_ports}*3
    ...                             ELSE IF           "${workflow}"=="ATT"   Set Variable    0
    ...                             ELSE                                     Set Variable    0
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${expected_flows}=    Run Keyword If    "${of_id}"=="${olt_flows_list}[${I}][olt]"
        ...    Evaluate    ${olt_flows_list}[${I}][flows]-${flows_onu}-${additional_flows_deleted}
        ...    ELSE    Set Variable    ${olt_flows_list}[${I}][flows]
        Wait Until Keyword Succeeds    ${timeout}    2s    Validate ONOS Flows per OLT    ${list_olts}[${I}][sn]
        ...    ${expected_flows}
    END
    ${flow}=    Execute ONOS CLI Command use single connection
    ...    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s any ${of_id}
    Log    ${flow}
    # validate etcd data
    ${List_ONU_Serial}    Create List
    Build ONU SN List    ${List_ONU_Serial}
    ${onu_sn_no_flows}=    Set Variable    ${hosts.src[0]['onu']}
    FOR  ${onu_sn}  IN  @{List_ONU_Serial}
        ${must_exist}=    Set Variable If    "${onu_sn}"=="${onu_sn_no_flows}"    False    True
        Wait Until Keyword Succeeds    ${timeout}    2s    Validate Tech Profiles and Flows in ETCD Data Per Onu
        ...    ${onu_sn}   ${INFRA_NAMESPACE}   ${kvstoreprefix}  ${must_exist}
    END
    ${onu_device_id_no_flows}=    Get Device ID From SN    ${hosts.src[0]['onu']}
    FOR  ${onu_device_id}  IN  @{onu_device_id_list}
        Log  ${onu_device_id}
        ${must_exist}=    Set Variable If    "${onu_device_id}"=="${onu_device_id_no_flows}"    False    True
        Validate OLT Flows Per Onu   ${onu_device_id}    ${must_exist}
    END

Do Wrong MDS Counter After Adapter Restart
    [Documentation]    This keyword checks correct handling of a wrong MDS counter after adapter restart
    ...    - perform sanity test include add subscriber
    ...    - restart the ONU adapter preferred via "kubectl delete pod"
    ...    - manipulate MDS counter
    ...    - wait until the restart of the ONU adapter and the reconcile processing are finished
    ...    - check all ONUs come up to previous state
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
    Reconcile Onu Adapter    ${NAMESPACE}    ${usekill2restart}    ACTIVE    wrong_MDS_counter=True
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
    Disable Onu Device
    Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
    ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    tech-profile-config-delete-success
    ...    ELSE       Current State Test All Onus    tech-profile-config-delete-success
    Wait for all ONU Ports in ONOS Disabled    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${unitag_sub}
    Enable Onu Device
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
