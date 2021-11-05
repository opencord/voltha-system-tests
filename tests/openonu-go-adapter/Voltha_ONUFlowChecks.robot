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
# FIXME Can we use the same test against BBSim and Hardware?

*** Settings ***
Documentation     Test of open ONU go adapter Flows
Suite Setup       Setup Suite
Test Setup        Setup
Test Teardown     Teardown
Suite Teardown    Teardown Suite
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
Resource          ../../variables/variables.robot
Resource          ../../libraries/power_switch.robot
Resource          ../../libraries/onu_utilities.robot

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
# KV Store Prefix
# example: -v kvstoreprefix:voltha_voltha
${kvstoreprefix}    voltha_voltha
# determines the environment workflow: DT, TT or ATT (default)
# example: -v workflow:DT
${workflow}    ATT
# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
# used tech profile, can be passed via the command line too, valid values: default (=1T1GEM), 1T4GEM, 1T8GEM
# example: -v techprofile:1T4GEM
${techprofile}    default
# if True execution will be paused before clean up, only use in case of manual testing, do not use in ci pipeline!
# example: -v pausebeforecleanup:True
${pausebeforecleanup}    False
${data_dir}    ../data

*** Test Cases ***
Flows Test
    [Documentation]    Validates onu vlan rules in etcd:
    [Tags]    functionalOnuGo    FlowsTest
    [Setup]    Start Logging    FlowsTest
    ${onu_tags_dict}=    Collect Tags Per ONU
    # Check and store vlan rules
    Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
    ...    Validate Etcd Vlan Rules Added Subscriber    ${onu_tags_dict}    defaultkvstoreprefix=${kvstoreprefix}
    #log flows for verification
    ${flowsresult}=    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s
    log     ${flowsresult}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        # Remove subscriber
        Do Onu Subscriber Remove Per OLT    ${of_id}    ${olt_serial_number}
    END
    #log flows for verification
    ${flowsresult}=    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s
    log     ${flowsresult}
    Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure    Run Keyword And Continue On Failure
    ...    Validate Etcd Vlan Rules Removed Subscriber   defaultkvstoreprefix=${kvstoreprefix}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Do Onu Subscriber Add Per OLT    ${of_id}    ${olt_serial_number}
    END
    #log flows for verification
    ${flowsresult}=    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    flows -s
    log     ${flowsresult}
    Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure    Run Keyword And Continue On Failure
    ...    Validate Etcd Vlan Rules Added Subscriber    ${onu_tags_dict}    defaultkvstoreprefix=${kvstoreprefix}
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND    Stop Logging    FlowsTest

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite inclusive enable device and sanity test of given workflow
    Common Test Suite Setup
    Start Logging    Setup-${SUITE NAME}
    ${techprofile}=    Set Variable If    "${techprofile}"=="1T1GEM"    default    ${techprofile}
    Set Suite Variable    ${techprofile}
    Run Keyword If    "${techprofile}"=="default"   Log To Console    \nTechProfile:default (1T1GEM)
    ...    ELSE IF    "${techprofile}"=="1T4GEM"    Set Tech Profile    1T4GEM    ${INFRA_NAMESPACE}
    ...    ELSE IF    "${techprofile}"=="1T8GEM"    Set Tech Profile    1T8GEM    ${INFRA_NAMESPACE}
    ...    ELSE    Fail    The TechProfile (${techprofile}) is not valid!
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    "${workflow}"=="DT"    Perform Sanity Test DT
    ...    ELSE IF    "${workflow}"=="TT"    Perform Sanity Tests TT
    ...    ELSE       Perform Sanity Test
    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...   AND    Stop Logging    Setup-${SUITE NAME}

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    ...    Furthermore gives the possibility to pause the execution.
    Start Logging    Teardown-${SUITE NAME}
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    Wait Until Keyword Succeeds    ${timeout}    1s    Validate Onu Data In Etcd    ${INFRA_NAMESPACE}    0    ${kvstoreprefix}
    ...    without_pm_data=False
    Wait for Ports in ONOS for all OLTs      ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  0   BBSM    ${timeout}
    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...   AND    Stop Logging    Teardown-${SUITE NAME}
    Close All ONOS SSH Connections
    Remove Tech Profile    ${INFRA_NAMESPACE}

Validate Etcd Vlan Rules Added Subscriber
    [Documentation]    This keyword validates Vlan rules of openonu-go-adapter Data stored in etcd.
    ...                It checks the match_vid (=4096) and set_vid when subscriber are added.
    [Arguments]    ${onu_tags_dict}    ${reqmatchvid}=4096    ${defaultkvstoreprefix}=voltha_voltha
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${etcddata}=    Get ONU Go Adapter ETCD Data    ${INFRA_NAMESPACE}    ${kvstoreprefix}    True    True
    #prepare result for json convert
    ${result}=    Prepare ONU Go Adapter ETCD Data For Json    ${etcddata}
    ${jsondata}=    To Json    ${result}
    ${length}=    Get Length    ${jsondata}
    log    ${jsondata}
    Should Not Be Empty     ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${flowparams}=    Get From Dictionary    ${value['uni_config'][0]}    flow_params
        ${onu}=    Get From Dictionary    ${value}    serial_number
        Validate Flow Params Vlan Rules    ${flowparams}    ${onu_tags_dict}    ${onu}    ${reqmatchvid}
    END

Validate Flow Params Vlan Rules
    [Documentation]    This keyword validates Vlan rules of openonu-go-adapter Data iterating over passed flow params.
    ...                It checks the match_vid (=4096) and set_vid when subscriber are added.
    [Arguments]    ${flowparams}    ${onu_tags_dict}    ${onu}    ${reqmatchvid}=4096
    ${length}=    Get Length    ${flowparams}
    ${nbofexpectedrules}=    Set Variable If
    ...    "${workflow}"=="TT" and ${has_dataplane}        4
    ...    "${workflow}"=="TT" and not ${has_dataplane}    3
    ...    "${workflow}"=="DT" or "${workflow}"=="ATT"     1
    Should Be Equal As Numbers    ${length}    ${nbofexpectedrules}
    ...    msg=wrong number of vlan rules (${length} != ${nbofexpectedrules})!
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${flowparams}    ${INDEX}
        ${matchvid}=    Get From Dictionary    ${value['vlan_rule_params']}
        ...    match_vid
        Should Be Equal As Integers    ${matchvid}    ${reqmatchvid}
        ${setvid}=    Get From Dictionary    ${value['vlan_rule_params']}
        ...    set_vid
        ${c_tags_list}=    Get From Dictionary    ${onu_tags_dict['${onu}']}    c_tags
        ${tagindex}=    Get Index From List    ${c_tags_list}   ${setvid}
        Should Not Be Equal As Integers    ${tagindex}    -1    msg=set_vid out of range (${setvid})!
    END

Validate Etcd Vlan Rules Removed Subscriber
    [Documentation]    This keyword validates Vlan rules of openonu-go-adapter Data stored in etcd.
    ...                It checks the match_vid (=4096) and set_vid when subscriber are removed.
    [Arguments]    ${reqmatchvid}=4096    ${defaultkvstoreprefix}=voltha_voltha
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${etcddata}=    Get ONU Go Adapter ETCD Data    ${INFRA_NAMESPACE}    ${kvstoreprefix}    True    True
    #prepare result for json convert
    ${result}=    Prepare ONU Go Adapter ETCD Data For Json    ${etcddata}
    ${jsondata}=    To Json    ${result}
    ${length}=    Get Length    ${jsondata}
    log    ${jsondata}
    Should Not Be Empty     ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        @{result_values}=    Run Keyword And Ignore Error
        ...    Get From Dictionary    ${value['uni_config'][0]['flow_params'][0]['vlan_rule_params']}    match_vid
        ${result}=       Set Variable    @{result_values}[0]
        ${matchvid}=     Set Variable    @{result_values}[1]
        Run Keyword If    "${workflow}"=="ATT"    Should Be Equal As Integers    ${matchvid}    ${reqmatchvid}
        ...    ELSE       Should Be Equal As Strings    ${result}    FAIL
        @{result_values}=    Run Keyword And Ignore Error
        ...    Get From Dictionary    ${value['uni_config'][0]['flow_params'][0]['vlan_rule_params']}   set_vid
        ${result}=       Set Variable    @{result_values}[0]
        ${setvid}=       Set Variable    @{result_values}[1]
        ${evalresult}=    Run Keyword If    "${workflow}"=="ATT"    Evaluate    ${setvid} == 4091
        ...               ELSE              Evaluate    "${result}" == "FAIL"
        Should Be True    ${evalresult}    msg=set_vid out of range (${setvid})!
    END

Collect Tags Per ONU
    [Documentation]    This keyword collects the s- and c-tags per ONU.
    ${onu_tags_dict}=     Create Dictionary
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_tags_dict}=    Run Keyword If  '${src['onu']}' in ${onu_tags_dict}   Update ONU Tags Dict    ${onu_tags_dict}
        ...                                  ${src['onu']}    ${src['c_tag']}    ${src['s_tag']}
        ...    ELSE    Append To ONU Tags Dict    ${onu_tags_dict}
        ...                                  ${src['onu']}    ${src['c_tag']}    ${src['s_tag']}
    END
    log    ${onu_tags_dict}
    [return]    ${onu_tags_dict}

Update ONU Tags Dict
    [Documentation]    This keyword update passed dictionary with the s- and c-tags for passed ONU.
    [Arguments]    ${onu_tags_dict}    ${onu}    ${c_tag}    ${s_tag}
    ${c_tag}=    Convert To Integer    ${c_tag}
    ${s_tag}=    Convert To Integer    ${s_tag}
    ${c_tags_list}=    Get From Dictionary    ${onu_tags_dict['${onu}']}    c_tags
    Append To List    ${c_tags_list}    ${c_tag}
    ${s_tags_list}=    Get From Dictionary    ${onu_tags_dict['${onu}']}    s_tags
    Append To List    ${s_tags_list}    ${s_tag}
    Set To Dictionary    ${onu_tags_dict['${onu}']}    c_tags    ${c_tags_list}    s_tags    ${s_tags_list}
    [return]    ${onu_tags_dict}

Append To ONU Tags Dict
    [Documentation]    This keyword append the s- and c-tags of passed ONU to passed dictionary .
    [Arguments]    ${onu_tags_dict}    ${onu}    ${c_tag}    ${s_tag}
    ${c_tag}=    Convert To Integer    ${c_tag}
    ${s_tag}=    Convert To Integer    ${s_tag}
    ${c_tags_list}=    Create List    ${c_tag}
    ${s_tags_list}=    Create List    ${s_tag}
    ${onu_dict}=    Create Dictionary    c_tags    ${c_tags_list}    s_tags    ${s_tags_list}
    Set To Dictionary    ${onu_tags_dict}    ${onu}    ${onu_dict}
    [return]    ${onu_tags_dict}
