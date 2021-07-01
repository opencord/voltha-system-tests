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
...               For voltha-infra prefix kafka. is needed e.g.: --set kafka.externalAccess.enabled=true
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
# when voltha is running in k8s port forwarding is needed
# example: -v PORT_FORWARDING:False
${PORT_FORWARDING}    True
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
Check Default Metrics All ONUs
    [Documentation]    Validates the ONU Go adapter pm date resp. Metrics with dafault values
    [Tags]    functional    CheckDefaultMetricsAllOnus
    [Setup]   Start Logging    CheckDefaultMetricsAllOnus
    ${collect_interval}=    Determine Collection Interval
    Collect and Validate PM Data    ${collect_interval}
    [Teardown]    Run Keywords    Clean Metric Dictionary
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    CheckDefaultMetricsAllOnus

Check User Onu Metrics
    [Documentation]    Validates the ONU Go adapter pm date resp. Metrics with user values
    ...                Currently only the intvals of metric groups UNI_Status and PON_Optical will be set to user values.
    [Tags]    functional    CheckUserOnuMetrics
    [Setup]   Start Logging    CheckUserOnuMetrics
    # set user values for intervals
    Set Group Interval All Onu    UNI_Status    ${ONU_UNI_STATUS_INTERVAL}
    Set Group Interval All Onu    PON_Optical   ${ONU_PON_OPTICAL_INTERVAL}
    ${collect_interval}=    Determine Collection Interval    user=True
    # activate user interval values
    Activate And Validate Interval All Onu    user=True
    Collect and Validate PM Data    ${collect_interval}    user=True
    # (re-)activate default interval values
    Set Group Interval All Onu    UNI_Status    -1
    Set Group Interval All Onu    PON_Optical   -1
    Activate And Validate Interval All Onu
    [Teardown]    Run Keywords    Clean Metric Dictionary
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    CheckUserOnuMetrics

Check User Onu Metrics Disabled Device
    [Documentation]    Validates the ONU Go adapter pm date resp. Metrics with user values for disabled device
    ...                Currently only the intvals of metric groups UNI_Status will be set to user values and validated.
    ...                First enable status will be validated, then all devices will be disabled and status will be validated.
    [Tags]    functional    CheckUserOnuMetricsDisabledDevice
    [Setup]   Start Logging    CheckUserOnuMetricsDisabledDevice
    # set user values for intervals
    Set Group Interval All Onu    UNI_Status    ${ONU_UNI_STATUS_INTERVAL}
    ${collect_interval}=    Determine Collection Interval    user=True
    # activate user interval values
    Activate And Validate Interval All Onu    user=True
    # read and store currents validation data
    ${group}=    Set Variable    UNI_Status
    ${oper_state}=    Set Variable    oper_status
    ${admin_state}=   Set Variable    uni_admin_state
    ${prev_validation_data_oper_state}=     Get Validation Operation All Onu   ${group}    ${oper_state}
    ${prev_validation_data_admin_state}=    Get Validation Operation All Onu   ${group}    ${admin_state}
    # change the validation data for oper_status and uni_admin_state of metric group UNI_Status
    ${enable}=        Set Variable    0
    ${disable}=       Set Variable    1
    ${enabled_check}=    Create Dictionary    operator=${eq}    operand=${enable}
    ${disabled_check}=   Create Dictionary    operator=${eq}    operand=${disable}
    ${ValidationEnabled}=    Create Dictionary    first=${enabled_check}    successor=${enabled_check}
    ${ValidationDisabled}=   Create Dictionary    first=${disabled_check}   successor=${disabled_check}
    # validate enabled status
    Set Validation Operation All Onu    ${group}    ${oper_state}    ${ValidationEnabled}
    Set Validation Operation All Onu    ${group}    ${admin_state}   ${ValidationEnabled}
    Collect and Validate PM Data    ${collect_interval}    user=True
    Clean Metric Dictionary
    # validate disabled status
    Set Validation Operation All Onu    ${group}    ${oper_state}    ${ValidationDisabled}
    Set Validation Operation All Onu    ${group}    ${admin_state}   ${ValidationDisabled}
    # disable (all) onu devices
    Disable Onu Device
    ${alternativeonustates}=  Create List     omci-flows-deleted    tech-profile-config-delete-success
    Current State Test All Onus    omci-admin-lock    alternativeonustate=${alternativeonustates}
    Log Ports
    #check no port is enabled in ONOS
    Wait for Ports in ONOS for all OLTs    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    0    BBSM
    Collect and Validate PM Data    ${collect_interval}    user=True
    Clean Metric Dictionary
    # enable (all) onu devices
    Enable Onu Device
    ${alternativeonustates}=  Create List     onu-reenabled
    Current State Test All Onus    omci-flows-pushed    alternativeonustate=${alternativeonustates}
    Log Ports    onlyenabled=True
    #check that all the UNI ports show up in ONOS again
    Wait for Ports in ONOS for all OLTs    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${num_all_onus}    BBSM    determine_number=True
    # validate enabled status (again)
    Set Validation Operation All Onu    ${group}    ${oper_state}    ${ValidationEnabled}
    Set Validation Operation All Onu    ${group}    ${admin_state}   ${ValidationEnabled}
    Collect and Validate PM Data    ${collect_interval}    user=True
    # (re-)set previous validation data
    Set Validation Operation Passed Onu   ${group}    ${oper_state}     ${prev_validation_data_oper_state}
    Set Validation Operation Passed Onu   ${group}    ${admin_state}    ${prev_validation_data_admin_state}
    # (re-)activate default interval values
    Set Group Interval All Onu    UNI_Status    -1
    Activate And Validate Interval All Onu
    [Teardown]    Run Keywords    Clean Metric Dictionary
    ...    AND    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    CheckUserOnuMetricsDisabledDevice


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    # set ${kafka} depending on environment in case of port-forward is needed
    ${rc}    ${kafka}=    Run Keyword If    ${PORT_FORWARDING}    Run and Return Rc and Output
    ...    kubectl get svc -n default | grep kafka-0-external | awk '{print $1}'
    Run Keyword If    ${PORT_FORWARDING}    Should Not Be Empty    ${kafka}    Service kafka-0-external not found
    # start port forwarding if needed (when voltha runs in k8s)
    ${portFwdHandle} =    Run Keyword If    ${PORT_FORWARDING}    Start Process
    ...    kubectl port-forward --address 0.0.0.0 --namespace default svc/${kafka} ${KAFKA_PORT}:${KAFKA_SVC_PORT} &
    ...    shell=true
    Set Suite Variable   ${portFwdHandle}
    Sleep    5s
    # open connection to read kafka bus
    Wait Until Keyword Succeeds     3x    5s
    ...    kafka.Connection Open    ${KAFKA_IP}    ${KAFKA_PORT}    voltha.events    timestamp_from=0
    # enable OLT(s) and bring up ONU(s)
    Setup
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    # prepare pm data matrix for validation
    ${METRIC_DICT}=     Create Metric Dictionary
    Set Suite Variable    ${METRIC_DICT}

Teardown Suite
    [Documentation]    tear down the test suite
    # close connection to kafka
    kafka.Connection Close
    # stop port forwarding if started
    Run Keyword If    ${PORT_FORWARDING}    Terminate Process    ${portFwdHandle}    kill=true
    # call common suite teardown
    utils.Teardown Suite
    Close All ONOS SSH Connections
