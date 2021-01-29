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
Documentation     Test states of ONU Go adapter with ATT workflows only (not for DT/TT workflow!)
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
# state to test variable, can be passed via the command line too, valid values: 1-6
# 1 -> activating-onu
# 2 -> starting-openomci
# 3 -> discovery-mibsync-complete
# 4 -> initial-mib-downloaded
# 5 -> tech-profile-config-download-success
# 6 -> omci-flows-pushed
# example: -v state2test:5
# example: -v state2test:omci-flows-pushed
${state2test}    6
# test mode variable, can be passed via the command line too, valid values: SingleState, Up2State, SingleStateTime
# example: -v testmode:SingleStateTime
${testmode}    SingleState
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
ONU State Test
    [Documentation]    Validates the ONU Go adapter states
    [Tags]    sanityOnuGo    StateTestOnuGo
    [Setup]    Run Keywords    Start Logging    ONUStateTest
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}
    Run Keyword If    "${testmode}"=="SingleState"    Do ONU Single State Test
    ...    ELSE IF    "${testmode}"=="Up2State"    Do ONU Up To State Test
    ...    ELSE IF    "${testmode}"=="SingleStateTime"    Do ONU Single State Test Time
    ...    ELSE    Fail    The testmode (${testmode}) is not valid!
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUStateTest

Check Loaded Tech Profile
    [Documentation]    Validates the loaded Tech Profile
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    ...    Check will be executed only the reached ONU state is 5 (tech-profile-config-download-success) or higher
    [Tags]    functionalOnuGo   CheckTechProfileOnuGo
    [Setup]    Start Logging    ONUCheckTechProfile
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Check Tech Profile
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUCheckTechProfile

Onu Port Check
    [Documentation]    Validates that all the UNI ports show up in ONOS
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    PortTestOnuGo
    [Setup]    Start Logging    ONUPortTest
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Onu Port Check
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUPortTest

Onu Etcd Data Check
    [Documentation]    Validates ONU data stored in ETCD
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    EtcdDataOnuGo
    [Setup]    Start Logging    ONUEtcdDataTest
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Onu Etcd Data Check
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUEtcdDataTest

Onu Flow Check
    [Documentation]    Validates the onu flows in ONOS and Voltha
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    FlowTestOnuGo
    [Setup]    Start Logging    ONUFlowTest
    Run Keyword If    '${onu_state}'=='omci-flows-pushed'    Do Onu Flow Check
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUFlowTest

Disable Enable Onu Device
    [Documentation]    Disables/enables ONU Device and check states
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    DisableEnableOnuGo
    [Setup]    Start Logging    DisableEnableONUDevice
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Disable Enable Onu Test
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    DisableEnableONUDevice

Power Off Power On Onu Device
    [Documentation]    Power off and Power on of all ONU Devices and check state
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    PowerOffPowerOnOnuGo
    [Setup]    Start Logging    PowerOffPowerOnONUDevice
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Power Off Power On Onu Device
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    PowerOffPowerOnONUDevice

Soft Reboot Onu Device
    [Documentation]    Reboots softly all ONU Devices and check state
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    SoftRebootOnuGo
    [Setup]    Start Logging    SoftRebootONUDevice
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Soft Reboot Onu Device
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    SoftRebootONUDevice

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    state2test:${state2test}, testmode:${testmode}, techprofile:${techprofile},
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    ...    print2console:${print2console}
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    # prepare skip message in yellow for console log
    ${skip}=  Evaluate  "\\033[33mSKIP\\033[0m"
    ${skipped}=  Evaluate  "\\033[33m${SPACE*14} ===> Test case above was skipped! <=== ${SPACE*15}\\033[0m"
    ${skip_message}    Catenate    ${skipped} | ${skip} |
    Set Suite Variable    ${skip_message}
    ${all_onu_timeout}=    Run Keyword If   ${num_all_onus}>4    Calculate Timeout   ${timeout}
    ...    ELSE    Set Variable    ${timeout}
    Set Suite Variable    ${all_onu_timeout}
    ${techprofile}=    Set Variable If    "${techprofile}"=="1T1GEM"    default    ${techprofile}
    Set Suite Variable    ${techprofile}
    Run Keyword If    "${techprofile}"=="default"   Log To Console    \nTechProfile:default (1T1GEM)
    ...    ELSE IF    "${techprofile}"=="1T4GEM"    Set Tech Profile    1T4GEM
    ...    ELSE IF    "${techprofile}"=="1T8GEM"    Set Tech Profile    1T8GEM
    ...    ELSE    Fail    The TechProfile (${techprofile}) is not valid!
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable  ${onos_ssh_connection}
    # map the passed onu state to reached and make it visible for test suite
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    ${state2test}
    Set Suite Variable    ${admin_state}
    Set Suite Variable    ${oper_status}
    Set Suite Variable    ${connect_status}
    Set Suite Variable    ${onu_state_nb}
    Set Suite Variable    ${onu_state}
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
    Validate Onu Data In Etcd    0
    Wait for Ports in ONOS for all OLTs      ${onos_ssh_connection}  0   BBSM    ${timeout}
    Close All ONOS SSH Connections
    Remove Tech Profile

Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
    Run Keyword If    ${has_dataplane}    Sleep    60s
    # Create a list of olt ids (logical and device_id)
    ${olt_ids}    Create List
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #create/preprovision device
        ${olt_device_id}=    Run Keyword If    "${list_olts}[${I}][type]" == "${None}"
        ...    Create Device    ${list_olts}[${I}][ip]    ${OLT_PORT}
        ...    ELSE    Create Device    ${list_olts}[${I}][ip]    ${OLT_PORT}    ${list_olts}[${I}][type]
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

Do ONU Up To State Test
    [Documentation]    This keyword performs Up2State Test
    ...    All states up to the passed have to be checked
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If   ${onu_state_nb}>=1
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=activating-onu
        Run Keyword If   ${onu_state_nb}>=2
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=starting-openomci
        Run Keyword If   ${onu_state_nb}>=3
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=discovery-mibsync-complete
        Run Keyword If   ${onu_state_nb}>=4
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=initial-mib-downloaded
        Run Keyword If   ${onu_state_nb}>=5
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=tech-profile-config-download-success
        Run Keyword If   ${onu_state_nb}>=6
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
    END

Do ONU Single State Test
    [Documentation]    This keyword performs SingleState Test
    ...    Only the passed state has to be checked
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
        ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
        ...    ${src['onu']}    onu=True    onu_reason=${onu_state}
    END

Do ONU Single State Test Time
    [Documentation]    This keyword performs SingleState Test with calculate running time
    ...    Only the passed state has to be checked and the duration each single onu adapter needed
    ...    will be calculated and printed out
    #${ListfinishedONUs}    Create List
    #Set Global Variable    ${ListfinishedONUs}
    Create File    ONU_Startup_Time.txt    This file contains the startup times of all ONUs.
    ${list_onus}    Create List
    Build ONU SN List    ${list_onus}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${all_onu_timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    ${onu_state}    ${list_onus}    ${timeStart}    print2console=${print2console}
    ...    output_file=ONU_Startup_Time.txt

Do Onu Port Check
    [Documentation]    Check that all the UNI ports show up in ONOS
    Wait for Ports in ONOS for all OLTs    ${onos_ssh_connection}    ${num_all_onus}    BBSM    ${timeout}

Do Onu Etcd Data Check
    [Documentation]    Check Onu data stored in etcd
    Validate Onu Data In Etcd

Do Onu Flow Check
    [Documentation]    This keyword iterate all OLTs and performs Do Onu Flow Checks Per OLT
    # Check and store vlan rules
    ${firstvlanrules}=    Run Keyword And Continue On Failure    Validate Vlan Rules In Etcd
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        # Verify Default Meter in ONOS (valid only for ATT)
        Do Onu Subscriber Add Per OLT    ${of_id}    ${olt_serial_number}   ${onu_count}
    END
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get NNI Port in ONOS    ${of_id}
        Set Global Variable    ${nni_port}
        # Verify Default Meter in ONOS (valid only for ATT)
        Do Onu Flow Check Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}   ${onu_count}
    END
    #log flows for verification
    ${flowsresult}=    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s
    log     ${flowsresult}
    #check  for previous state is kept (normally omci-flows-pushed)
    Sleep    10s
    Run Keyword And Continue On Failure    Current State Test All Onus    ${state2test}
    ${secondvlanrules}=    Run Keyword And Continue On Failure    Validate Vlan Rules In Etcd    nbofcookieslice=3
    ...    prevvlanrules=${firstvlanrules}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get NNI Port in ONOS    ${of_id}
        Set Global Variable    ${nni_port}
        # Verify Default Meter in ONOS (valid only for ATT)
        Do Onu Subscriber Remove Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}   ${onu_count}
    END
    #check  for previous state is kept (normally omci-flows-pushed)
    Sleep    10s
    Run Keyword If    ${print2console}    Log    \r\nStart State Test All Onus.    console=yes
    Run Keyword And Continue On Failure    Current State Test All Onus    ${state2test}
    Run Keyword If    ${print2console}    Log    \r\nFinished State Test All Onus.    console=yes
    Run Keyword And Continue On Failure    Validate Vlan Rules In Etcd    prevvlanrules=${firstvlanrules}
    ...                                    setvidequal=True

Do Onu Subscriber Add Per OLT
    [Documentation]    Add Subscriber per OLT
    [Arguments]    ${of_id}    ${olt_serial_number}    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${print2console}    Log    \r\n[${I}] volt-add-subscriber-access ${of_id} ${onu_port}.
        ...   console=yes
    END

Do Onu Flow Check Per OLT
    [Documentation]    Checks all ONU flows show up in ONOS and Voltha
    [Arguments]    ${of_id}    ${nni_port}    ${olt_serial_number}    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
        ${logoutput}    Catenate    \r\n[${I}] Verify Subscriber Access Flows Added For
        ...    ONU ${of_id}    ${onu_port}    ${src['c_tag']}    ${src['s_tag']}.
        Run Keyword If    ${print2console}    Log    ${logoutput}    console=yes
    END

Do Onu Subscriber Remove Per OLT
    [Documentation]    Removes per OLT subscribers in ONOS and Voltha
    [Arguments]    ${of_id}    ${nni_port}    ${olt_serial_number}    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-remove-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${print2console}    Log    \r\n[${I}] volt-remove-subscriber-access ${of_id} ${onu_port}.
        ...    console=yes
    END

Do Check Tech Profile
    [Documentation]    This keyword checks the loaded TechProfile
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${stackname}=    Get Stack Name
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${stackname}/technology_profiles/XGS-PON/64'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    ${num_gem_ports}=    Set Variable    1
    ${num_gem_ports}=    Set Variable If
    ...    "${techprofile}"=="default"   1
    ...    "${techprofile}"=="1T4GEM"    4
    ...    "${techprofile}"=="1T8GEM"    8
    @{resultList}    Split String    ${result}     separator=,
    ${num_of_count_matches}=    Get Match Count    ${resultList}    "num_gem_ports": ${num_gem_ports}
    ...    whitespace_insensitive=True
    ${num_of_expected_matches}=    Evaluate    ${num_all_onus}
    Should Be Equal As Integers    ${num_of_expected_matches}    ${num_of_count_matches}
    ...    TechProfile (${TechProfile}) not loaded correctly:${num_of_count_matches} of ${num_of_expected_matches}

Do Disable Enable Onu Test
    [Documentation]    This keyword disables/enables all onus and checks the states.
    [Arguments]    ${state2check}=${state2test}    ${checkstatebeforedisable}=True
    ...    ${state2checkafterdisable}=tech-profile-config-delete-success
    Run Keyword If    ${checkstatebeforedisable}    Current State Test All Onus    ${state2check}
    Disable Onu Device
    ${alternative_onu_reason}=    Set Variable If
    ...    '${state2checkafterdisable}'=='tech-profile-config-delete-success'    omci-flows-deleted
    ...    '${state2checkafterdisable}'=='omci-admin-lock'    tech-profile-config-delete-success    ${EMPTY}
    ${alternativeonustates}=  Create List     ${alternative_onu_reason}
    Current State Test All Onus    ${state2checkafterdisable}    alternativeonustate=${alternativeonustates}
    Log Ports
    #check no port is enabled in ONOS
    Wait for Ports in ONOS for all OLTs    ${onos_ssh_connection}    0    BBSM
    Enable Onu Device
    Current State Test All Onus    ${state2check}
    Log Ports    onlyenabled=True
    #check that all the UNI ports show up in ONOS again
    Wait for Ports in ONOS for all OLTs    ${onos_ssh_connection}    ${num_all_onus}    BBSM

Do Power Off Power On Onu Device
    [Documentation]    This keyword power off/on all onus and checks the states.
    Power Off ONU Device    ${namespace}
    Sleep    5s
    ${alternativeonustates}=  Create List     omci-flows-deleted
    Current State Test All Onus    tech-profile-config-delete-success
    ...    ENABLED    DISCOVERED    UNREACHABLE    alternativeonustate=${alternativeonustates}
    Power On ONU Device    ${namespace}
    Current State Test All Onus    ${state2test}

Do Soft Reboot Onu Device
    [Documentation]    This keyword reboots softly all onus and checks the states.
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Reboot ONU    ${onu_device_id}   False
    END
    ${alternativeonustates}=  Create List     omci-flows-deleted
    Run Keyword Unless    ${has_dataplane}    Current State Test All Onus    tech-profile-config-delete-success
    ...   ENABLED    DISCOVERED    REACHABLE    alternativeonustate=${alternativeonustates}
    Sleep    5s
    Run Keyword Unless    ${has_dataplane}    Do Disable Enable Onu Test    checkstatebeforedisable=False
    ...    state2checkafterdisable=omci-admin-lock
    Run Keyword If    ${has_dataplane}    Current State Test All Onus    omci-flows-pushed
    Do Onu Port Check
