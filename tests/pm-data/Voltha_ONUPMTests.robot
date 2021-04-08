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
Documentation     Test of open ONU go adapter PM data
...               in case of kafka pod runs in k8s cluster - kafka has to deploy with following EXTRA_HELM_FLAGS
...               --set externalAccess.enabled=true,
...               --set externalAccess.service.type=NodePort,
...               --set externalAccess.service.nodePorts[0]=${KAFKA_PORT},
...               --set externalAccess.service.domain=${KAFKA_IP}
...               with e.g. service.domain=10.0.02.15 or 127.0.0.1 and service.nodePorts[0]=30201!
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
Resource          ../../libraries/pm_utilities.robot
Resource          ../../variables/variables.robot

Library           kafka_robot.KafkaClient    log_level=DEBUG    WITH NAME    kafka
Library           grpc_robot.VolthaTools     WITH NAME    volthatools


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

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
# determines the environment workflow: DT, TT or ATT (default)
# example: -v workflow:DT
${workflow}    ATT
# kafka ip e.g. ip of master host where k8s is running
# example: -v KAFKA_IP:10.0.2.15
${KAFKA_IP}    127.0.0.1
# kafka port: port of kafka nodeport
# example: -v KAFKA_PORT:30201
${KAFKA_PORT}    30201
# kafka service port: service port of kafka nodeport
# example: -v KAFKA_SVC_PORT:9094
${KAFKA_SVC_PORT}    9094
# onu pm data default interval
# example: -v ONU_DEFAULT_INTERVAL:50s
${ONU_DEFAULT_INTERVAL}    300s
# onu pm data group PON_Optical interval
# example: -v ONU_PON_OPTICAL_INTERVAL:50s
${ONU_PON_OPTICAL_INTERVAL}    35s
# onu pm data group UNI_Status interval
# example: -v ONU_UNI_STATUS_INTERVAL:50s
${ONU_UNI_STATUS_INTERVAL}    20s

*** Test Cases ***
Dummy Test
    [Documentation]    Does nothing, only for test purposes needed, will be deleted
    [Tags]    Dummy
    [Setup]   Start Logging    Dummy
    Log     Dummy Test
    Log    ${METRIC_DICT}
    [Teardown]    Stop Logging    Dummy


Check Default Metrics All ONUs
    [Documentation]    Validates the ONU Go adapter pm date resp. Metrics with dafault values
    [Tags]    functional    CheckDefaultMetricsAllOnus
    [Setup]   Start Logging    CheckDefaultMetricsAllOnus
    log    get longest interval    console=yes
    ${longest_interval}=    Get Longest Interval
    log    get metrics ${longest_interval}s    console=yes
    ${collect_interval}=    evaluate    ((${longest_interval}*2)+(${longest_interval}*0.2))
    ${Kafka_Records}=    Get Metrics    ${collect_interval}s
    ${RecordsLength}=    Get Length    ${Kafka_Records}
    FOR    ${Index}    IN RANGE    0    ${RecordsLength}
        ${metric}=    Set Variable    ${Kafka_Records[${Index}]}
        ${message}=    Get From Dictionary  ${metric}  message
        ${event}=    volthatools.Events Decode Event   ${message}    return_default=true
        Continue For Loop If    not 'kpi_event2' in ${event}
        ${slice}=    Get Slice Data From Event    ${event}
        Validate Slice Data   ${slice}    ${Kafka_Records}
        Set Previous Record    ${Index}    ${slice}
    END
    Validate Number of Checks
    [Teardown]    Run Keywords    Clean Metric Dictionary
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    CheckDefaultMetricsAllOnus

Check User Onu Metrics
    [Documentation]    Validates the ONU Go adapter pm date resp. Metrics with user values
    [Tags]    functional    CheckUserOnuMetrics
    [Setup]   Start Logging    CheckUserOnuMetrics
    Set Group Interval All Onu    UNI_Status    ${ONU_UNI_STATUS_INTERVAL}
    Set Group Interval All Onu    PON_Optical   ${ONU_PON_OPTICAL_INTERVAL}
    ${longest_interval}=    Get Longest Interval    user=True
    ${collect_interval}=    evaluate    ((${longest_interval}*2)+(${longest_interval}*0.2))
    # activate user interval values
    Activate And Validate Interval All Onu    user=True
    ${Kafka_Records}=    Get Metrics    ${collect_interval}s
    ${RecordsLength}=    Get Length    ${Kafka_Records}
    FOR    ${Index}    IN RANGE    0    ${RecordsLength}
        ${metric}=    Set Variable    ${Kafka_Records[${Index}]}
        ${message}=    Get From Dictionary  ${metric}  message
        ${event}=    volthatools.Events Decode Event   ${message}    return_default=true
        Continue For Loop If    not 'kpi_event2' in ${event}
        ${slice}=    Get Slice Data From Event    ${event}
        Validate Slice Data   ${slice}    ${Kafka_Records}
        Set Previous Record    ${Index}    ${slice}
    END
    Validate Number of Checks    user=True
    # (re-)activate default interval values
    Activate And Validate Interval All Onu
    [Teardown]    Run Keywords    Clean Metric Dictionary
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    CheckUserOnuMetrics



*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    # start port forwarding
    ${portFwdHandle} =    Start Process
    ...    kubectl port-forward --address 0.0.0.0 --namespace default svc/kafka-0-external ${KAFKA_PORT}:${KAFKA_SVC_PORT} &
    ...    shell=true
    Set Suite Variable   ${portFwdHandle}
    Sleep    5s
    # open connection to read kafka bus, timestamp_from=0 is necessary due kafka timestamp is always -1 in ONF environment
    Wait Until Keyword Succeeds     3x    5s
    ...    kafka.Connection Open    ${KAFKA_IP}    ${KAFKA_PORT}    voltha.events    timestamp_from=0
    # enable OLT(s) and bring up ONU(s)
    log    Start Setup    console=yes
    Setup
    log    Start Sanity Check    console=yes
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    log    Prepare Metrics    console=yes
    # prepare pm data matrix for validation
    ${METRIC_DICT}=     Create Metric Dictionary
    Set Suite Variable    ${METRIC_DICT}

Teardown Suite
    [Documentation]    tear down the test suite
    # close connection to kafka
    kafka.Connection Close
    # stop port forwarding
    Terminate Process    ${portFwdHandle}    kill=true
    # call common suite teardown
    utils.Teardown Suite


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# will be moved to voltctl.robot - begin
Read Default Interval From Pmconfig
    [Documentation]    Reads default interval from pm config
    [Arguments]    ${device_id}
    ${rc}    ${result}=    Run and Return Rc and Output    voltctl device pmconfig get ${device_id}
    Should Be Equal As Integers    ${rc}    0
    log    ${result}
    @{words}=    Split String    ${result}
    ${interval}=    Get From List    ${words}    3
    # workaround until voltctl printouts contain the unit (s)
    ${interval}=    Catenate    SEPARATOR=    ${interval}    s
    log    ${interval}
    [return]    ${interval}

Read Group Interval From Pmconfig
    [Documentation]    Reads default interval from pm config
    [Arguments]    ${device_id}    ${group}
    ${rc}    ${result}=    Run and Return Rc and Output     voltctl device pmconfig group list ${device_id} | grep ${group}
    Should Be Equal As Integers    ${rc}    0
    log    ${result}
    @{words}=    Split String    ${result}
    ${interval}=    Get From List    ${words}    -1
    # workaround until voltctl printouts contain the unit (s)
    ${interval}=    Catenate    SEPARATOR=    ${interval}    s
    log    ${interval}
    [return]    ${interval}

Set and Validate Default Interval
    [Documentation]    Sets and validates default interval of pm data
    [Arguments]    ${device_id}    ${interval}
    ${rc}    ${result}=    Run and Return Rc and Output    voltctl device pmconfig frequency set ${device_id} ${interval}
    Should Be Equal As Integers    ${rc}    0
    log    ${result}
    ${interval}=    Get Substring    ${interval}    0    -1
    Should Contain    ${result}    ${interval}

Set and Validate Group Interval
    [Documentation]    Sets and validates group interval of pm data
    [Arguments]    ${device_id}    ${interval}    ${group}
    ${rc}    ${result}=    Run and Return Rc and Output    voltctl device pmconfig group set ${device_id} ${group} ${interval}
    Should Be Equal As Integers    ${rc}    0
    ${rc}    ${result}=    Run and Return Rc and Output     voltctl device pmconfig group list ${device_id} | grep ${group}
    Should Be Equal As Integers    ${rc}    0
    log    ${result}
    ${interval}=    Get Substring    ${interval}    0    -1
    Should Contain    ${result}    ${interval}

Read Group List
    [Documentation]    Reads metric group list of given device
    [Arguments]    ${device_id}
    ${rc}    ${result}=    Run and Return Rc and Output    voltctl device pmconfig group list ${device_id} | grep -v GROUPNAME
    Should Be Equal As Integers    ${rc}    0
    ${group_list}    Create List
    ${interval_dict}     Create Dictionary
    @{output}=    Split String    ${result}    \n
    FOR    ${Line}    IN     @{output}
        @{words}=    Split String    ${Line}
        ${group}=    Set Variable    ${words[0]}
        ${interval}=    Set Variable    ${words[2]}
        Append To List    ${group_list}    ${group}
        Set To Dictionary    ${interval_dict}    ${group}=${interval}
    END
    [return]    ${group_list}    ${interval_dict}

Read Group Metric List
    [Documentation]    Reads group metric list of given device and group
    [Arguments]    ${device_id}    ${group}
    ${cmd}=    Catenate    voltctl device pmconfig groupmetric list ${device_id} ${group} | grep -v SAMPLEFREQ
    ${rc}    ${result}=    Run and Return Rc and Output    ${cmd}
    Should Be Equal As Integers    ${rc}    0
    ${groupmetric_list}    Create List
    @{output}=    Split String    ${result}    \n
    FOR    ${Line}    IN     @{output}
        @{words}=      Split String    ${Line}
        ${name}=      Set Variable    ${words[0]}
        ${type}=       Set Variable    ${words[1]}
        ${enabled}=    Set Variable    ${words[2]}
        ${subdict}=       Create Dictionary    type=${type}    enabled=${enabled}
        ${dict}=       Create Dictionary    ${name}=${subdict}
        Append To List    ${groupmetric_list}    ${dict}
    END
    [return]    ${groupmetric_list}

Read Group Metric Dict
    [Documentation]    Reads group metric list of given device and group
    [Arguments]    ${device_id}    ${group}
    ${cmd}=    Catenate    voltctl device pmconfig groupmetric list ${device_id} ${group} | grep -v SAMPLEFREQ
    ${rc}    ${result}=    Run and Return Rc and Output    ${cmd}
    Should Be Equal As Integers    ${rc}    0
    ${groupmetric_dict}    Create Dictionary
    @{output}=    Split String    ${result}    \n
    FOR    ${Line}    IN     @{output}
        @{words}=      Split String    ${Line}
        ${name}=      Set Variable    ${words[0]}
        ${type}=       Set Variable    ${words[1]}
        ${enabled}=    Set Variable    ${words[2]}
        ${subdict}=       Create Dictionary    type=${type}    enabled=${enabled}
        Set To Dictionary    ${groupmetric_dict}    ${name}=${subdict}
    END
    [return]    ${groupmetric_dict}

# will be moved to voltctl.robot - end
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

