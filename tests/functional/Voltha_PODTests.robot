#Copyright 2017-present Open Networking Foundation
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
Documentation     Test various end-to-end scenarios
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
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot

*** Variables ***
${POD_NAME}       flex-ocp-cord
${KUBERNETES_CONF}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}    ~/pod-configs/kubernetes-configs
#${KUBERNETES_CONFIGS_DIR}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${timeout}        60s
${num_onus}       1
${of_id}          0
${logical_id}     0
${ports_per_onu}    5
${has_dataplane}    True
${external_libs}    True
${teardown_device}    False

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanity    test1
    #[Setup]    Clean Up Linux
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${onu_serial_number}
    ...   ${of_id}
    Wait Until Keyword Succeeds    ${timeout}    2s    Verify Eapol Flows Added For ONU    ${k8s_node_ip}
    ...    ${ONOS_SSH_PORT}    ${onu_port}
    Run Keyword If    ${has_dataplane}    Validate Authentication    True    ${src0['dp_iface_name']}
    ...    wpa_supplicant.conf    ${src0['ip']}    ${src0['user']}    ${src0['pass']}
    ...    ${src0['container_type']}    ${src0['container_name']}
    Wait Until Keyword Succeeds    ${timeout}    2s    Verify Number of AAA-Users    ${k8s_node_ip}    ${ONOS_SSH_PORT}
    ...    ${num_onus}
    Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
    ...    volt-add-subscriber-access ${of_id} ${onu_port}
    Run Keyword If    ${has_dataplane}    Validate DHCP and Ping    True    True    ${src0['dp_iface_name']}
    ...    ${src0['s_tag']}    ${src0['c_tag']}    ${dst0['dp_iface_ip_qinq']}    ${src0['ip']}    ${src0['user']}
    ...    ${src0['pass']}    ${src0['container_type']}    ${src0['container_name']}    ${dst0['dp_iface_name']}
    ...    ${dst0['ip']}    ${dst0['user']}    ${dst0['pass']}    ${dst0['container_type']}    ${dst0['container_name']}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate DHCP Allocations    ${k8s_node_ip}    ${ONOS_SSH_PORT}
    ...    ${num_onus}

*** Keywords ***
Setup Suite
    [Documentation]    Setup the whole test suite
    # BBSim sanity test doesn't need these imports from other repositories
    Run Keyword If    ${external_libs}    Import Library
    ...    ${CURDIR}/../../../voltha/tests/atests/common/testCaseUtils.py
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/Subscriber.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/OLT.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/DHCP.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/Kubernetes.robot
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${export_kubeconfig}    export KUBECONFIG=${KUBERNETES_CONF}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
    Check CLI Tools Configured
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${k8s_node_ip}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    Set Global Variable    ${export_kubeconfig}    export KUBECONFIG=${KUBERNETES_CONF}
    ${olt_ip}=    Evaluate    ${olts}[0].get("ip")
    ${olt_user}=    Evaluate    ${olts}[0].get("user")
    ${olt_pass}=    Evaluate    ${olts}[0].get("pass")
    ${olt_serial_number}=    Evaluate    ${olts}[0].get("serial")
    ${onu_serial_number}=    Evaluate    ${onus}[0].get("serial")
    Set Suite Variable    ${olt_serial_number}
    Set Suite Variable    ${onu_serial_number}
    Set Suite Variable    ${olt_ip}
    Set Suite Variable    ${olt_user}
    Set Suite Variable    ${olt_pass}
    Set Suite Variable    ${k8s_node_ip}
    Set Suite Variable    ${k8s_node_user}
    Set Suite Variable    ${k8s_node_pass}
    @{container_list}=    Create List
    Append To List    ${container_list}    adapter-open-olt
    Append To List    ${container_list}    adapter-open-onu
    Append To List    ${container_list}    voltha-api-server
    Append To List    ${container_list}    voltha-ro-core
    Append To List    ${container_list}    voltha-rw-core-11
    Append To List    ${container_list}    voltha-rw-core-12
    Append To List    ${container_list}    voltha-ofagent
    Set Suite Variable    ${container_list}
    # Set Deployment Config Variables seems like a candidate for refactoring.
    # BBSim doesn't need it right now.
    Run Keyword If    ${external_libs}    Set Deployment Config Variables
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}


Setup
    [Documentation]    Pre-test Setup
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ${olt_serial_number}    ENABLED    ACTIVE
    ...    REACHABLE
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ${onu_serial_number}    ENABLED    ACTIVE
    ...    REACHABLE    onu=True    onu_reason=tech-profile-config-download-success
    ${onu_device_id}=    Get Device ID From SN    ${onu_serial_number}
    Set Suite Variable    ${onu_device_id}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}

Teardown
    [Documentation]    kills processes and cleans up interfaces on src+dst servers
    Get Device Output from Voltha    ${olt_device_id}
    #Get Logical Device Output from Voltha    ${logical_id}
    Run Keyword If    ${external_libs}    Get ONOS Status    ${k8s_node_ip}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${external_libs}    Log Kubernetes Containers Logs Since Time    ${datetime}    ${container_list}

Teardown Suite
    [Documentation]    Clean up device if desired
    Run Keyword If    ${teardown_device}    Delete Device and Verify
    Run Keyword If    ${teardown_device}    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
    ...    device-remove ${of_id}

Clean Up Linux
    [Documentation]    Kill processes and clean up interfaces on src+dst servers
    Run Keyword And Ignore Error    Kill Linux Process    [w]pa_supplicant    ${src0['ip']}
    ...    ${src0['user']}    ${src0['pass']}    ${src0['container_type']}    ${src0['container_name']}
    Run Keyword And Ignore Error    Kill Linux Process    [d]hclient    ${src0['ip']}
    ...    ${src0['user']}    ${src0['pass']}    ${src0['container_type']}    ${src0['container_name']}
    Run Keyword If    '${dst0['ip']}' != '${None}'    Run Keyword And Ignore Error
    ...    Kill Linux Process    [d]hcpd    ${dst0['ip']}    ${dst0['user']}
    ...    ${dst0['pass']}    ${dst0['container_type']}    ${dst0['container_name']}
    Delete IP Addresses from Interface on Remote Host    ${src0['dp_iface_name']}    ${src0['ip']}
    ...    ${src0['user']}    ${src0['pass']}    ${src0['container_type']}    ${src0['container_name']}
    Run Keyword If    '${dst0['ip']}' != '${None}'    Delete Interface on Remote Host
    ...    ${dst0['dp_iface_name']}.${src0['s_tag']}    ${dst0['ip']}    ${dst0['user']}    ${dst0['pass']}
    ...    ${dst0['container_type']}    ${dst0['container_name']}

Delete Device and Verify
    [Documentation]    Disable -> Delete devices via voltctl and verify its removed
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${onu_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ${onu_serial_number}    DISABLED    UNKNOWN
    ...    REACHABLE
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${onu_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed    ${onu_device_id}
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device    ${olt_serial_number}    DISABLED    UNKNOWN
    ...    REACHABLE
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed    ${olt_device_id}
