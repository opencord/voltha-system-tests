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
Documentation     Test of open ONU error cases
...               The test suite validates special error scenarios of openonu_go_adapter
...               -- power off during mib download
...               -- power of during flow configuration
...               -- onu capabilities against configuration requirements priority queues
...               -- onu capabilities against configuration requirements tconts
...               see also VOL-4796
...               In case of kafka pod runs in k8s cluster - kafka has to deploy with following EXTRA_HELM_FLAGS
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
# if True execution will be paused before clean up, only use in case of manual testing, do not use in ci pipeline!
# example: -v pausebeforecleanup:True
${pausebeforecleanup}    False
# flag for first test, needed due default timeout in BBSim to mimic OLT reboot of 60 seconds
${firsttest}    True
# determines the environment workflow: DT, TT or ATT (default)
# example: -v workflow:DT
${workflow}    ATT
# KV Store Prefix
# example: -v kvstoreprefix:voltha/voltha_voltha
${kvstoreprefix}    voltha/voltha_voltha
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
${data_dir}    ../data

# flag to choose the subscriber provisioning command type in ONOS
# TT often provision a single services for a subscriber (eg: hsia, voip, ...) one after the other.
# if set to True, command used is "volt-add-subscriber-unitag"
# if set to False, comand used is "volt-add-subscriber-access"
${unitag_sub}    False

*** Test Cases ***
Verify Power Off During MIB Downloading
    [Documentation]    Validates the ONU Go adapter regarding robustness in case of ONU power-off during MIB downloading
    [Tags]    functional    PowerOffWhileMibDownload
    [Setup]    Run Keywords    Start Logging    PowerOffWhileMibDownload
    ...    AND    Setup Test
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    Current State Test All Onus    starting-openomci
    Power Off ONU Device    ${namespace}
    Current State Test All Onus    stopping-openomci
    Power On ONU Device    ${namespace}
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If  ${logging}    Collect Logs
    ...    AND    Delete All Devices and Verify
    ...    AND    Delete MIB Template Data    ${INFRA_NAMESPACE}
    ...    AND    Stop Logging    PowerOffWhileMibDownload

Verify Power Off During Flow Configuration
    [Documentation]    Validates the ONU Go adapter regarding robustness in case of ONU power-off during flow configuration
    ...                see VOL-4828
    [Tags]    functional    PowerOffWhileFlowConfig
    [Setup]    Run Keywords    Start Logging    PowerOffWhileFlowConfig
    ...    AND    Setup Test
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    ${state2test}=    Set Variable If
    ...    "${workflow}"=="DT"    initial-mib-downloaded
    ...    "${workflow}"=="TT"    initial-mib-downloaded
    ...    "${workflow}"=="ATT"   omci-flows-pushed
    ...    initial-mib-downloaded
    Current State Test All Onus    ${state2test}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Do Onu Subscriber Add Per OLT    ${of_id}    ${olt_serial_number}   ${print2console}
    END
    Power Off ONU Device    ${namespace}
    Current State Test All Onus    stopping-openomci
    Power On ONU Device    ${namespace}
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT    ${suppressaddsubscriber}
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT   ${suppressaddsubscriber}
    ...    ELSE       Perform Sanity Test    ${suppressaddsubscriber}
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If  ${logging}    Collect Logs
    ...    AND    Delete All Devices and Verify
    ...    AND    Delete MIB Template Data    ${INFRA_NAMESPACE}
    ...    AND    Stop Logging    PowerOffWhileFlowConfig

Verify ONU capabilities against configuration requirements Priority Queues
    [Documentation]    Validates the ONU capabilities against configuration requirements regarding number of priority queues.
    ...                Require more priority queues than ONU capabilities. Check for correct reason/state of ONU and kafka
    ...                message.
    ...                see VOL-4827
    [Tags]    functional    ONUCapabilitiesVsConfigReqPrioQueues
    [Setup]   Run Keywords    Start Logging    ONUCapabilitiesVsConfigReqPrioQueues
    ...    AND    Set Tech Profile   1T65GEM-error-case-priority-queues
    ...    AND    Setup Test
    kafka.Records Clear
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    ${state2test}=    Set Variable If
    ...    "${workflow}"=="DT"    initial-mib-downloaded
    ...    "${workflow}"=="TT"    initial-mib-downloaded
    ...    "${workflow}"=="ATT"   stopping-openomci
    ...    initial-mib-downloaded
    Current State Test All Onus    ${state2test}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        #in case of ATT no flows have to configured. leave loop
        Exit For Loop If    "${workflow}"=="ATT"
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Do Onu Subscriber Add Per OLT   ${of_id}   ${olt_serial_number}  ${print2console}
    END
    ${alternativeonustates}=  Create List     omci-flows-deleted
    Current State Test All Onus    stopping-openomci    alternativeonustate=${alternativeonustates}
    ${list_onu_device_id}    Create List
    Build ONU Device Id List    ${list_onu_device_id}
    ${event}=    Set Variable    ONU_CONFIG_FAILURE_MISSING_US_PRIORITY_QUEUE
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Events All ONUs    ${list_onu_device_id}    ${event}
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If  ${logging}    Collect Logs
    ...    AND    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    ...    AND    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    ...    AND    Set Suite Variable    ${TechProfile}    ${EMPTY}
    ...    AND    Remove Tech Profile    ${INFRA_NAMESPACE}
    ...    AND    Delete All Devices and Verify
    ...    AND    Get ONU Go Adapter ETCD Data    ${INFRA_NAMESPACE}    ${kvstoreprefix}
    ...    AND    Delete MIB Template Data    ${INFRA_NAMESPACE}
    ...    AND    Stop Logging    ONUCapabilitiesVsConfigReqPrioQueues

Verify ONU capabilities against configuration requirements TConts
    [Documentation]    Validates the ONU capabilities against configuration requirements regarding number of tconts.
    ...                Require more tconts than ONU capabilities. Check for correct reason/state of ONU and kafka message
    ...                VOL-4826
    ...                Hint: Run this test case using bbsim-kind-multi-uni-tt.yaml!
    [Tags]    functionalMultiUni    ONUCapabilitiesVsConfigReqTConts
    [Setup]   Run Keywords    Start Logging    ONUCapabilitiesVsConfigReqTConts
    ...    AND    Set Tech Profile   1T1GEM-multi-instances     ${INFRA_NAMESPACE}    64
    ...    AND    Set Tech Profile   1T1GEM-multi-instances     ${INFRA_NAMESPACE}    65
    ...    AND    Set Tech Profile   1T1GEM-multi-instances     ${INFRA_NAMESPACE}    66
    ...    AND    Setup Test
    kafka.Records Clear
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
    ${state2test}=    Set Variable If
    ...    "${workflow}"=="DT"    initial-mib-downloaded
    ...    "${workflow}"=="TT"    initial-mib-downloaded
    ...    "${workflow}"=="ATT"   omci-flows-pushed
    ...    initial-mib-downloaded
    Current State Test All Onus    ${state2test}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Do Onu Subscriber Add Per OLT    ${of_id}    ${olt_serial_number}   ${print2console}
    END
    ${alternativeonustates}=  Create List     omci-flows-deleted
    Current State Test All Onus    stopping-openomci    alternativeonustate=${alternativeonustates}
    ${list_onu_device_id}    Create List
    Build ONU Device Id List    ${list_onu_device_id}
    ${list_onu_device_id}    Create List
    Build ONU Device Id List    ${list_onu_device_id}
    ${event}=    Set Variable    ONU_CONFIG_FAILURE_MISSING_TCONT
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Events All ONUs    ${list_onu_device_id}    ${event}
    [Teardown]    Run Keywords    Printout ONU Serial Number and Device Id    print2console=${print2console}
    ...    AND    Run Keyword If  ${logging}    Collect Logs
    ...    AND    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    ...    AND    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    ...    AND    Set Suite Variable    ${TechProfile}    ${EMPTY}
    ...    AND    Remove Tech Profile    ${INFRA_NAMESPACE}
    ...    AND    Remove Tech Profile    ${INFRA_NAMESPACE}    65
    ...    AND    Remove Tech Profile    ${INFRA_NAMESPACE}    66
    ...    AND    Delete All Devices and Verify
    ...    AND    Get ONU Go Adapter ETCD Data    ${INFRA_NAMESPACE}    ${kvstoreprefix}
    ...    AND    Delete MIB Template Data    ${INFRA_NAMESPACE}
    ...    AND    Stop Logging    ONUCapabilitiesVsConfigReqTConts

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Start Logging Setup or Teardown    Setup-${SUITE NAME}
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
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # delete etcd onu data
    Delete ONU Go Adapter ETCD Data    namespace=${INFRA_NAMESPACE}    validate=True
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
    # delete etcd MIB Template Data
    Delete MIB Template Data    ${INFRA_NAMESPACE}
    # delete etcd onu data
    Delete ONU Go Adapter ETCD Data    namespace=${INFRA_NAMESPACE}    validate=True
    Close All ONOS SSH Connections

Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
    Run Keyword If    ${has_dataplane}    Sleep    60s
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
# [EOF] - delta:force
