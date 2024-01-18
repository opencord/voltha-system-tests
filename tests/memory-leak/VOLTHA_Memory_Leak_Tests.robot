# Copyright 2022-2024 Open Networking Foundation (ONF) and the ONF Contributors
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

# Use bbsim-kind-dt-1OLTx1PONx2ONU.yaml

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
Library           ../../libraries/utility.py    WITH NAME    utility
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
${iterations}    50
# address of Prometheus
# example: -v prometheusaddr:0.0.0.0
${prometheusaddr}    0.0.0.0
# port of Prometheus
# example: -v prometheusport:31301
${prometheusport}    31301

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

*** Test Cases ***
Memory Leak Test Openonu Go Adapter
    [Documentation]   Test of try to catch memory leak in Openonu Go Adapter for all three workflows, ATT, DT and TT
    ...    Multiple run of Flow and ONU setup and teardown to try to catch memory leak.
    ...    Setup OLT and one (first) ONU, both will kept over the whole test
    ...    Setup a second ONU and do following in specified loops (iterations):
    ...    - do workflow related sanity test (bring up onu to omci flows pushed and setup flows)
    ...    - remove flows
    ...    - delete ONU
    ...    - wait for onu auto detect
    ...    Attention: Due VOL-4703 is not corrected memory leak tests will run in pipeline for DT workflow only!
    ...               This is a temporaly workaround only! Has to be checked after introduction of voltha-go-controller.
    [Tags]    functionalMemoryLeak    MemoryLeakTestOnuGo
    [Setup]    Run Keywords    Start Logging    MemoryLeakTestOnuGo
    ...  AND   Append Memory Consumption To File    isTest=True    action=test_start
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    ${output_file_onu}=    Catenate    SEPARATOR=/    ${OUTPUT DIR}    MemoryConsumptionsOpenOnuAdapterOnuTest.txt
    Create File    ${output_file_onu}   This file contains the memory consumptions of openonu adapter.
    Append To File    ${output_file_onu}   \r\nTest: ${TEST NAME}
    ${start_mem_consumption_onu}=    Get And Write Memory Consumption Per Container To File    adapter-open-onu    ${NAMESPACE}
    ...    ${output_file_onu}    Start    settling_memory=True
    ${Device_Setup}=    Set Variable    True
    Set Global Variable    ${Device_Setup}
    Setup
    Get And Write Memory Consumption Per Container To File    adapter-open-onu    ${NAMESPACE}
    ...    ${output_file_onu}    Setup-OLT    #settling_memory=True
    Append Memory Consumption To File    isTest=True    action=test_setup
    # Start first ONU
    ${src_onu_1}=    Set Variable    ${hosts.src[${0}]}
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src_onu_1['onu']}
    ${onu_reason}=  Set Variable If    "${workflow}"=="DT"    initial-mib-downloaded
    ...                                "${workflow}"=="TT"    initial-mib-downloaded
    ...                                "${workflow}"=="ATT"   omci-flows-pushed
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    ${onu_reason}
    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${src_onu_1['onu']}    onu=True    onu_reason=${onu_state}
    ${setup_mem_consumption_onu}=    Get And Write Memory Consumption Per Container To File    adapter-open-onu    ${NAMESPACE}
    ...    ${output_file_onu}    Setup-ONU-1    settling_memory=True
    # Start second ONU
    ${src_onu_2}=    Set Variable    ${hosts.src[${1}]}
    ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     bbsim0
    Power On ONU    ${NAMESPACE}    ${bbsim_pod}    ${src_onu_2['onu']}
    ${onu_reason}=  Set Variable If    "${workflow}"=="DT"    initial-mib-downloaded
    ...                                "${workflow}"=="TT"    initial-mib-downloaded
    ...                                "${workflow}"=="ATT"   omci-flows-pushed
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    ${onu_reason}
    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${src_onu_2['onu']}    onu=True    onu_reason=${onu_state}
    Get And Write Memory Consumption Per Container To File   adapter-open-onu   ${NAMESPACE}   ${output_file_onu}   Setup-ONU-2
    Append Memory Consumption To File    isTest=True    action=test_setup_onu2
    FOR    ${I}    IN RANGE    1    ${iterations} + 1
        Run Keyword If    ${print2console}    Log    \r\nStart iteration ${I} of ${iterations}.    console=yes
        Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
        ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
        ...    ELSE       Perform Sanity Test
        Sleep    5s
        Run Keyword If    ${print2console}    Log    Remove Flows.    console=yes
        # Remove Flows
        ${src}=    Set Variable    ${hosts.src[1]}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${src_onu_2['olt']}
        ${onu_sn_2}=     Set Variable    ${src_onu_2['onu']}
        ${onu_port_2}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${onu_sn_2}
        ...    ${of_id}    ${src_onu_2['uni_id']}
        Remove Flows Conditional    ${unitag_sub}    ${onu_sn_2}    ${of_id}    ${onu_port_2}
        Run Keyword If    ${print2console}    Log    Check Flows removed.    console=yes
        # Check All Flows Removed
        ${expected_flows_onu}=    Set Variable If   "${workflow}"=="ATT"    1    0
        Wait Until Keyword Succeeds    ${timeout}    2s    Validate number of flows    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${expected_flows_onu}  ${of_id}   any    ${onu_port_2}
        # Delete Device
        Run Keyword If    ${print2console}    Log    Get ONU Device IDs.    console=yes
        ${onu_device_id}=    Get Device ID From SN    ${onu_sn_2}
        Run Keyword If    ${print2console}    Log    Delete ONU. (device id: ${onu_device_id})    console=yes
        Wait Until Keyword Succeeds    ${timeout}    1s    Delete Device    ${onu_device_id}
        Run Keyword If    ${print2console}    Log    Wait for ONU come back.    console=yes
        ${onu_device_id_list}=    Create List    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    1s  Check for new ONU Device IDs    ${onu_device_id_list}
        ${list_onus}    Create List
        Build ONU SN List    ${list_onus}
        Wait Until Keyword Succeeds    ${timeout}    1s    Check all ONU OperStatus     ${list_onus}  ACTIVE
        Build ONU SN List    ${list_onus}
        ${onu_reason}=  Set Variable If    "${workflow}"=="DT"    initial-mib-downloaded
        ...                                "${workflow}"=="TT"    initial-mib-downloaded
        ...                                "${workflow}"=="ATT"   omci-flows-pushed
        Wait Until Keyword Succeeds    ${timeout}    1s
        ...    Validate Device    ENABLED  ACTIVE  REACHABLE    ${onu_sn_2}    onu_reason=${onu_reason}    onu=True
        ${formatedIt}=    Format String    {:>3}    ${I}
        Get And Write Memory Consumption Per Container To File    adapter-open-onu    ${NAMESPACE}    ${output_file_onu}
        ...    Iteration ${formatedIt}
    END
    # Switch off second ONU
    Power Off ONU    ${NAMESPACE}    ${bbsim_pod}    ${src_onu_2['onu']}
    Wait Until Keyword Succeeds    500s    30s
    ...        Validate Memory Consumptions  adapter-open-onu  ${NAMESPACE}  ${setup_mem_consumption_onu}  ${output_file_onu}
    ...        out_string=Validate
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Append Memory Consumption To File    isTest=True    compare_to=test_setup
    ...    AND    Run Keyword And Ignore Error    Wait Until Keyword Succeeds    300s    30s
    ...           Validate Memory Consumptions  adapter-open-onu  ${NAMESPACE}  ${start_mem_consumption_onu}  ${output_file_onu}
    ...    AND    Append Memory Consumption To File    isTest=True    compare_to=test_start
    ...    AND    Stop Logging    MemoryLeakTestOnuGo

Memory Leak Test Openolt Adapter
    [Documentation]   Test of try to catch memory leak in Openolt Adapter for all three workflows, ATT, DT and TT
    ...    Multiple run of OLT setup and teardown to try to catch memory leak.
    ...    - do workflow related sanity test (bring up onu to omci flows pushed and setup flows)
    ...    - delete OLT devices
    ...    - wait for OLT is removed
    ...    - add and enable OLT again
    ...    - wait for ONUs available again
    ...    Hint: Also memory consumptions of Openonu GO Adapter will be validated!
    ...    Hint: default timePower On ONU Device    ${NAMESPACE}out in BBSim to mimic OLT reboot is 60 seconds!
    ...    This behaviour of BBSim can be modified by 'oltRebootDelay: 60' in BBSim section of helm chart or
    ...    used values.yaml during 'voltha up'.
    ...    Attention: Due VOL-4703 is not corrected memory leak tests will run in pipeline for DT workflow only!
    ...               This is a temporaly workaround only! Has to be checked after introduction of voltha-go-controller.
    [Tags]    functionalMemoryLeak    MemoryLeakTestOlt
    [Setup]    Run Keywords    Start Logging    MemoryLeakTestOlt
    ...  AND   Append Memory Consumption To File    isTest=True    action=test_start
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    ${output_file_olt}=    Catenate    SEPARATOR=/    ${OUTPUT DIR}    MemoryConsumptionsOpenOltAdapterOltTest.txt
    Create File    ${output_file_olt}   This file contains the memory consumptions of openolt adapter.
    Append To File    ${output_file_olt}   \r\nTest: ${TEST NAME}
    ${output_file_onu}=    Catenate    SEPARATOR=/    ${OUTPUT DIR}    MemoryConsumptionsOpenOnuAdapterOltTest.txt
    Create File    ${output_file_onu}   This file contains the memory consumptions of openonu adapter.
    Append To File    ${output_file_onu}   \r\nTest: ${TEST NAME}
    Run Keyword If    ${print2console}    Log    \r\nStart ${iterations} iterations.    console=yes
    ${start_mem_consumption_olt}=    Get And Write Memory Consumption Per Container To File    adapter-open-olt    ${NAMESPACE}
    ...    ${output_file_olt}    Start    settling_memory=True
    ${start_mem_consumption_onu}=    Get And Write Memory Consumption Per Container To File    adapter-open-onu    ${NAMESPACE}
    ...    ${output_file_onu}    Start
    ${Device_Setup}=    Set Variable    True
    Set Global Variable    ${Device_Setup}
    Setup
    Power On ONU Device    ${NAMESPACE}
    ${setup_mem_consumption_olt}=    Get And Write Memory Consumption Per Container To File    adapter-open-olt    ${NAMESPACE}
    ...    ${output_file_olt}    Setup    settling_memory=True
    Append Memory Consumption To File    isTest=True    action=test_setup
    Get And Write Memory Consumption Per Container To File    adapter-open-onu    ${NAMESPACE}    ${output_file_onu}    Setup
    FOR    ${I}    IN RANGE    1    ${iterations} + 1
        Run Keyword If    ${print2console}    Log    \r\nStart iteration ${I} of ${iterations}.    console=yes
        Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
        ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
        ...    ELSE       Perform Sanity Test
        Sleep    5s
        Run Keyword If    ${print2console}    Log    Delete OLTs.    console=yes
        Delete Devices In Voltha    Type=openolt
        Run Keyword If    ${print2console}    Log    Check OLTs removed.    console=yes
        Wait Until Keyword Succeeds    ${timeout}    1s    Test Empty Device List
        Sleep    20s
        Run Keyword If    ${print2console}    Log    Add OLTs (calling Setup).    console=yes
        Setup
        Power On ONU Device    ${NAMESPACE}
        Run Keyword If    ${print2console}    Log    Wait for ONUs come back.    console=yes
        ${list_onus}    Create List
        Build ONU SN List    ${list_onus}
        Wait Until Keyword Succeeds    ${timeout}    1s    Check all ONU OperStatus     ${list_onus}  ACTIVE
        Build ONU SN List    ${list_onus}
        ${onu_reason}=  Set Variable If    "${workflow}"=="DT"    initial-mib-downloaded
        ...                                "${workflow}"=="TT"    initial-mib-downloaded
        ...                                "${workflow}"=="ATT"   omci-flows-pushed
        Wait Until Keyword Succeeds    ${timeout}    1s
        ...    Validate ONU Devices  ENABLED  ACTIVE  REACHABLE    ${list_onus}    onu_reason=${onu_reason}
        ${formatedIt}=    Format String    {:>3}    ${I}
        Get And Write Memory Consumption Per Container To File    adapter-open-olt    ${NAMESPACE}    ${output_file_olt}
        ...    Iteration ${formatedIt}
        Get And Write Memory Consumption Per Container To File    adapter-open-onu    ${NAMESPACE}    ${output_file_onu}
        ...    Iteration ${formatedIt}
    END
    Wait Until Keyword Succeeds    500s    30s
    ...        Validate Memory Consumptions  adapter-open-olt  ${NAMESPACE}  ${setup_mem_consumption_olt}  ${output_file_onu}
    ...        out_string=Validate
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If    ${logging}    Get Logical Id of OLT
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Teardown Test
    ...    AND    Append Memory Consumption To File    isTest=True    compare_to=test_setup
    ...    AND    Run Keyword And Ignore Error    Wait Until Keyword Succeeds    300s    30s
    ...           Validate Memory Consumptions  adapter-open-olt  ${NAMESPACE}  ${start_mem_consumption_olt}  ${output_file_olt}
    ...    AND    Validate Memory Consumptions  adapter-open-onu  ${NAMESPACE}  ${start_mem_consumption_onu}  ${output_file_onu}
    ...    AND    Append Memory Consumption To File    isTest=True    compare_to=test_start
    ...    AND    Stop Logging    MemoryLeakTestOlt


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
    Create Global Memory Consumption File
    ${Device_Setup}=    Set Variable    False
    Set Global Variable    ${Device_Setup}
    ${Start_Time}=    Get Time    epoch
    Set Global Variable    ${Start_Time}
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
    Append Memory Consumption To File    compare_to=suite_setup
    ${End_Time}=    Get Time    epoch
    FOR    ${container}     IN      @{list_of_container}
        ${mem_consumption}=   utility.get_memory_consumptions_range   ${prometheusaddr}:${prometheusport}   ${container}
        ...                   ${namespace}    ${Start_Time}    ${End_Time}
        Write Memory Consumption File Per Container    ${container}    ${mem_consumption}
    END
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log  ${consumption_max}  Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device} and ${Device_Setup}    Delete All Devices and Verify
    Run Keyword Unless    ${etcdcheckintestteardown}    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Onu Data In Etcd    ${INFRA_NAMESPACE}    0    ${kvstoreprefix}    without_pm_data=False
    Run Keyword If   ${Device_Setup}   Wait for Ports in ONOS for all OLTs  ${ONOS_SSH_IP}  ${ONOS_SSH_PORT}  0  BBSM  ${timeout}
    Run Keyword If   ${logging}    Collect Logs
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
    Run Keyword If    ${teardown_device} and ${Device_Setup}      Delete All Devices and Verify
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # check etcd data are empty
    Run Keyword If    ${etcdcheckintestteardown}    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Onu Data In Etcd    ${INFRA_NAMESPACE}    0    ${kvstoreprefix}    without_pm_data=False
    Sleep    5s

Create Global Memory Consumption File
    [Documentation]    Creates global memory consumption file and read the start values
    ${list_of_container}=   Create List    voltha    ofagent    adapter-open-olt    adapter-open-onu
    Set Global Variable    ${list_of_container}
    ${global_output_file}=    Catenate    SEPARATOR=/    ${OUTPUT DIR}    MemoryConsumptions${workflow}.txt
    Create File  ${global_output_file}  This file contains the memory consumptions of all voltha adapter of workflow ${workflow}.
    Set Global Variable    ${global_output_file}
    ${time}=    Get Time
    Append To File    ${global_output_file}   \r\n------------------------------------------------------
    Append To File    ${global_output_file}   \r\nMemory consumptions Suite Setup at ${time}
    Append To File    ${global_output_file}   \r\n------------------------------------------------------
    &{suite_setup}    Create Dictionary
    FOR    ${container}     IN      @{list_of_container}
        ${mem_consumption}=    Append Memory Consumption Per Container To File    ${container}
        Set To Dictionary    ${suite_setup}    ${container}    ${mem_consumption}
    END
    &{memory_consumption_dict}    Create Dictionary    suite_setup    ${suite_setup}
    Set Global Variable    ${memory_consumption_dict}

Append Memory Consumption To File
    [Documentation]    Appends data to global memory consumption file per container
    [Arguments]    ${isTest}=False    ${action}=${EMPTY}    ${output_file}=${global_output_file}    ${compare_to}=${EMPTY}
    ${time}=    Get Time
    ${TestOrSuite}    Set Variable If    ${isTest}    Test    Suite
    ${SetupOrTeardown}    Set Variable If    "${action}"!="${EMPTY}"    Setup/Start (${action})    Teardown
    Append To File    ${global_output_file}   \r\n------------------------------------------------------
    Append To File    ${global_output_file}   \r\nMemory consumptions ${TestOrSuite} ${SetupOrTeardown} at ${time}
    Run Keyword If    ${isTest}    Append To File    ${global_output_file}   \r\nTest: ${TEST NAME}
    Append To File    ${global_output_file}   \r\n------------------------------------------------------
    &{test_setup}    Create Dictionary
    FOR    ${container}     IN      @{list_of_container}
        ${mem_consumption}=    Append Memory Consumption Per Container To File    ${container}    output_file=${output_file}
        ...    compare_to=${compare_to}
        Run Keyword If    "${action}"!="${EMPTY}"    Set To Dictionary    ${test_setup}    ${container}    ${mem_consumption}
    END
    Run Keyword If    "${action}"!="${EMPTY}"    Set To Dictionary    ${memory_consumption_dict}    ${action}    ${test_setup}
    Run Keyword If    "${action}"!="${EMPTY}"    Set Global Variable    ${memory_consumption_dict}

Append Memory Consumption Per Container To File
    [Documentation]    Appends data to global memory consumption file per container
    [Arguments]    ${container}    ${namespace}=${NAMESPACE}    ${output_file}=${global_output_file}    ${compare_to}=${EMPTY}
    ${mem_consumption}=    Wait Until Keyword Succeeds    300s    5s
    ...    Get Memory Consumptions    ${prometheusaddr}    ${prometheusport}    ${container}   ${namespace}
    ${formated_mem}=    Format String    {:>10}    ${mem_consumption}
    ${prestring}=    Catenate    \r\nMemory consumptions of   ${container}
    ${formated_prestring}=    Format String    {:<43}    ${prestring}
    ${poststring}=    Run Keyword If    "${compare_to}"!="${EMPTY}"    Compare Memory Consumptions    ${mem_consumption}
    ...    ${container}    ${compare_to}
    ...    ELSE   Set Variable    ${EMPTY}
    ${out_string}=   Catenate   ${formated_prestring}    :    ${formated_mem} Bytes    ${poststring}
    Append To File    ${output_file}   ${out_string}
    [return]    ${mem_consumption}

Compare Memory Consumptions
    [Documentation]    Compares the current memory consumptions with the compare-to value of passed container and
    ...                creates corresponding string.
    [Arguments]    ${mem_consumption}    ${container}    ${compare_to}
    ${compare_value}=       Get From Dictionary    ${memory_consumption_dict['${compare_to}']}    ${container}
    ${diff_value}=          Evaluate    ${mem_consumption}-${compare_value}
    ${percentage_value}=    Evaluate    100*${mem_consumption}/${compare_value}
    ${percentage_value}=    Convert To Number    ${percentage_value}    2
    ${formated_start}=      Format String    {:>10}    ${compare_value}
    ${formated_diff}=       Format String    {:>10}    ${diff_value}
    ${formated_perc}=       Format String    {:>7}     ${percentage_value}
    ${out_string}=   Catenate   : Corresponds ${formated_perc}% compared to ${compare_to} (${formated_start} Bytes) :
    ...    Difference: ${formated_diff} Bytes
    [return]    ${out_string}

Get And Write Memory Consumption Per Container To File
    [Documentation]    Gets and write current memory consumptions to memory consumption file per container
    [Arguments]    ${container}    ${namespace}   ${output_file}    ${addstring}=${EMPTY}   ${settling_memory}=False
    ${mem_consumption}=    Run Keyword If    ${settling_memory}    Settling Memory Consumptions    ${prometheusaddr}
    ...           ${prometheusport}    ${container}   ${namespace}
    ...    ELSE   Wait Until Keyword Succeeds    60s    5s    Get Memory Consumptions    ${prometheusaddr}    ${prometheusport}
    ...           ${container}   ${namespace}
    ${time}=    Get Time
    ${formated_mem}=    Format String    {:>10}    ${mem_consumption}
    ${prestring}=    Catenate    Memory consumptions of   ${container}    ${addstring}
    ${formated_prestring}=    Format String    {:<54}    ${prestring}
    ${out_string}=   Catenate   \r\n${formated_prestring}    :    ${formated_mem} Bytes    at ${time}
    Append To File    ${output_file}   ${out_string}
    Run Keyword If    ${print2console}    Log    ${formated_prestring} : ${formated_mem} Bytes at ${time}    console=yes
    [return]    ${mem_consumption}

Check for new ONU Device IDs
    [Documentation]    Checks that no old onu device ids stay
    [Arguments]    ${old_device_ids}
    ${new_device_ids}=    Get ONUs Device IDs from Voltha
    Should Not Be Empty    ${new_device_ids}    No new ONU device IDs
    FOR    ${item}    IN    @{old_device_ids}
        List Should Not Contain Value    ${new_device_ids}    ${item}    Old device id ${item} still present.
    END

Validate Memory Consumptions
    [Documentation]    Validates memory consumptions of passed POD
    [Arguments]    ${container}    ${namespace}    ${start_value}    ${output_file}    ${out_string}=Teardown
    ${mem_consumption}=    Get And Write Memory Consumption Per Container To File    ${container}    ${namespace}
    ...    ${output_file}    ${out_string}
    ${mem_consumption}=   Convert To Number    ${mem_consumption}    1
    ${upper_bound}=    Evaluate    (${start_value} + (${start_value}*0.175))
    Should Be True    ${upper_bound} >= ${mem_consumption}

Settling Memory Consumptions
    [Documentation]    Delivers memory consumptions of passed POD after memory consumptions are leveled.
    ...                - collecting memory consumption at least about 5 minutes, but max 20 minutes
    ...                - built average of memory consumtions
    ...                - wait current value does not deviate from the average by more than 12%.
    ...                - deliver average value value
    [Arguments]    ${prometheusaddr}    ${prometheusport}    ${container}    ${namespace}
    @{consumption_list}=    Create List
    ${consumption_sum}=    Set Variable    0
    ${consumption_max}=    Set Variable    0
    ${average_value}=    Set Variable    0
    FOR    ${index}    IN RANGE    1    21
        ${current_consumptions}=  Get Memory Consumptions  ${prometheusaddr}  ${prometheusport}  ${container}  ${namespace}
        Append To List    ${consumption_list}    ${current_consumptions}
        ${consumption_sum}=    Evaluate     ${consumption_sum}+${current_consumptions}
        ${consumption_max}=    Set Variable If    ${current_consumptions}>${consumption_max}    ${current_consumptions}
        ...                    ${consumption_max}
        ${average_value}=    Evaluate    ${consumption_sum}/${index}
        ${upper_bound}=    Evaluate    (${average_value} + (${average_value}*0.12))
        ${lower_bound}=    Evaluate    (${average_value} - (${average_value}*0.12))
        ${time}=    Get Time
        ${formatedIt}=    Format String    {:>3}    ${index}
        ${formated_mem}=    Format String    {:>10}    ${current_consumptions}
        ${prestring}=    Catenate    Memory consumptions of   ${container}    Leveling    ${formatedIt}
        ${formated_prestring}=    Format String    {:<54}    ${prestring}
        Run Keyword If    ${print2console}    Log    ${formated_prestring} : ${formated_mem} Bytes at ${time}    console=yes
        Exit For Loop If   ${index}>5 and ${current_consumptions}<${upper_bound} and ${current_consumptions}>${lower_bound}
        Sleep    60s
    END
    [return]   ${average_value}

Get Memory Consumptions
    [Documentation]    Delivers memory consumptions of passed POD
    [Arguments]    ${prometheusaddr}    ${prometheusport}    ${container}    ${namespace}
    ${mem_consumption}=    utility.get_memory_consumptions    ${prometheusaddr}:${prometheusport}    ${container}   ${namespace}
    Should Be True    ${mem_consumption} > 0
    [return]    ${mem_consumption}

Write Memory Consumption File Per Container
    [Documentation]    Writes memory consumptions file of passed POD for later evaluation.
    [Arguments]    ${container}    ${mem_consumption}
    ${output_file}=    Catenate    SEPARATOR=/    ${OUTPUT DIR}    MemoryConsumptions${workflow}${container}.txt
    Create File  ${output_file}
    FOR    ${value}     IN      @{mem_consumption}
        ${epoch}=    Convert To String    ${value[0]}
        Append To File    ${output_file}    ${epoch},${value[1]}${\n}
    END
