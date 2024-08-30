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

*** Settings ***
Documentation     Test of open ONU go adapter MIB audit
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
Resource          ../../variables/variables.robot

Library           kafka_robot.KafkaClient    log_level=DEBUG    WITH NAME    kafka
Library           grpc_robot.VolthaTools     WITH NAME    volthatools


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
# onu MIB audit interval
# example: -v ONU_MIB_AUDIT_INTERVAL:50s
${ONU_MIB_AUDIT_INTERVAL}    60s
# MDS mitsmatches per ONU
# example: -v MDS_MISMATCHES_PER_ONU:2
${MDS_MISMATCHES_PER_ONU}    3
# if True execution will be paused before clean up, only use in case of manual testing, do not use in ci pipeline!
# example: -v pausebeforecleanup:True
${pausebeforecleanup}    False
# if True some outputs to console are done during running tests e.g. long duration flow test
# example: -v print2console:True
${print2console}    False
${suppressaddsubscriber}    True

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

*** Test Cases ***
Check Mib Audit
    [Documentation]    Validates the ONU Go adapter MIB audit
    [Tags]    functional    CheckMibAudit
    [Setup]   Start Logging    CheckMibAudit
    kafka.Records Clear
    ${interval}=    Calculate Interval    ${ONU_MIB_AUDIT_INTERVAL}
    FOR    ${I}    IN RANGE     1    ${MDS_MISMATCHES_PER_ONU} + 1
        Run Keyword If    ${print2console}    Log    \r\nInvalidate MDS ${I} of ${MDS_MISMATCHES_PER_ONU}.    console=yes
        Set Wrong MDS Counter All ONUs   ${NAMESPACE}
        ${list_onu_device_id}    Create List
        Build ONU Device Id List    ${list_onu_device_id}
        Run Keyword If    ${print2console}    Log    Check for device events that indicate a failed MDS check.    console=yes
        ${event}=    Set Variable    ONU_MIB_AUDIT_FAILURE_MDS
        Wait Until Keyword Succeeds    ${interval}    5s    Validate Events All ONUs    ${list_onu_device_id}    ${event}
        kafka.Records Clear
        Run Keyword If    ${print2console}    Log    Sanity Test after MIB Audit.    console=yes
        Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
        ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
        ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
        Run Keyword If    ${print2console}    Log    Disable ONUs.    console=yes
        Disable Onu Device
        Run Keyword If    "${workflow}"=="DT"    Current State Test All Onus    omci-admin-lock
        ...    ELSE IF    "${workflow}"=="TT"    Current State Test All Onus    tech-profile-config-delete-success
        ...    ELSE       Current State Test All Onus    tech-profile-config-delete-success
        #check all ports are disabled in ONOS
        Wait for all ONU Ports in ONOS Disabled    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${unitag_sub}
        Run Keyword If    ${print2console}    Log    Enable ONUs.    console=yes
        Enable Onu Device
        Run Keyword If    ${print2console}    Log    Sanity Test after Enable ONUs.    console=yes
        Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT     ${suppressaddsubscriber}
        ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT    ${suppressaddsubscriber}
        ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
    END
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If  ${logging}    Collect Logs
    ...    AND    Stop Logging    CheckMibAudit


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Start Logging Setup or Teardown    Setup-${SUITE NAME}
    # set tech profiles
    ${preload_tech_profile}=   Set Variable If   ${unitag_sub} and "${workflow}"=="TT" and not ${has_dataplane}   True   False
    Set Suite Variable    ${preload_tech_profile}
    Run Keyword If   ${preload_tech_profile}   Set Tech Profile   TT-HSIA                                ${INFRA_NAMESPACE}    64
    Run Keyword If   ${preload_tech_profile}   Set Tech Profile   TT-VoIP                                ${INFRA_NAMESPACE}    65
    Run Keyword If   ${preload_tech_profile}   Set Tech Profile   TT-multi-uni-MCAST-AdditionalBW-None   ${INFRA_NAMESPACE}    66
    Common Test Suite Setup
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    # set ${kafka} depending on environment in case of port-forward is needed
    ${rc}    ${kafka}=    Run Keyword If    ${PORT_FORWARDING}    Run and Return Rc and Output
    ...    kubectl get svc -n ${INFRA_NAMESPACE} | grep kafka-0-external | awk '{print $1}'
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
    Stop Logging Setup or Teardown    Setup-${SUITE NAME}

Teardown Suite
    [Documentation]    tear down the test suite
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    # close connection to kafka
    kafka.Connection Close
    # stop port forwarding if started
    Run Keyword If    ${PORT_FORWARDING}    Terminate Process    ${portFwdHandle}    kill=true
    # call common suite teardown
    utils.Teardown Suite
    Close All ONOS SSH Connections
    Set Suite Variable    ${TechProfile}    ${EMPTY}
    Run Keyword If    ${preload_tech_profile}    Remove Tech Profile    ${INFRA_NAMESPACE}    64
    Run Keyword If    ${preload_tech_profile}    Remove Tech Profile    ${INFRA_NAMESPACE}    65
    Run Keyword If    ${preload_tech_profile}    Remove Tech Profile    ${INFRA_NAMESPACE}    66

Calculate Interval
    [Documentation]    Converts the passed value in seconds, adds percentage and return it w/o unit
    ...                Conversion to string is needed to remove float format!
    [Arguments]    ${val}    ${percentage}=0.2    ${unit}=True
    ${seconds}=    Convert Time    ${val}
    ${seconds}=    evaluate    ${seconds}+${seconds}*0.2
    ${seconds}=    Convert To String    ${seconds}
    ${seconds}=    Get Substring    ${seconds}    0    -2
    ${seconds}=    Set Variable If    ${unit}    ${seconds}s    ${seconds}
    RETURN    ${seconds}
