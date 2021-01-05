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

*** Settings ***
Documentation     Provide the function to perform system related test
Suite Setup       Common Test Suite Setup
Test Setup        Setup
Test Teardown     Teardown
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/voltha.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot

*** Variables ***
${timeout}        120s
${desired_ETCD_cluster_size}    3
${minimal_ETCD_cluster_size}    2
${namespace}      voltha
${ETCD_namespace}    default
${ETCD_resources}    statefulsets
${ETCD_name}      etcd
${ETCD_pod_label_key}    app
${common_pod_label_key}    app
${rwcore_pod_label_value}    rw-core
${ofagent_pod_label_value}    ofagent
${adapter_openolt_pod_label_value}    adapter-open-olt
${teardown_device}      false

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
ETCD Scale Test
    [Documentation]    Perform the sanity test if some ETCD endpoints crash
    [Tags]    functional    bbsim
    [Setup]    Run Keywords    Start Logging    EtcdScaleTest
    ...        AND    Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND    Teardown Suite
    ...           AND    Stop Logging    EtcdScaleTest
    ${current_size}=    Get ETCD Replica Count    ${ETCD_namespace}
    Pass Execution If    '${current_size}' != '${desired_ETCD_cluster_size}'
    ...    'Skip the test if the cluster size smaller than minimal size 3'
    # The minimal cluster size after scale down
    # based on https://github.com/ETCD-io/ETCD/blob/master/Documentation/faq.md#what-is-failure-tolerance
    Scale ETCD    ${ETCD_namespace}    ${minimal_ETCD_cluster_size}
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Validate ETCD Size    ${ETCD_namespace}    ${minimal_ETCD_cluster_size}
    # Perform the sanity-test
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    # We scale up the size to 3, the recommended size of ETCD cluster.
    Scale ETCD    ${ETCD_namespace}    ${desired_ETCD_cluster_size}
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Validate ETCD Size    ${ETCD_namespace}    ${desired_ETCD_cluster_size}
    # Perform the sanity-test again
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

ETCD Failure Test
    [Documentation]    Failure Scenario Test: ETCD Crash
    [Tags]    FailureTest
    [Setup]    Start Logging    EtcdFailureTest
    [Teardown]    Run Keywords    Collect Logs
    ...              AND    Stop Logging    EtcdFailureTest
    Delete K8s Pods By Label    ${ETCD_namespace}    ${ETCD_pod_label_key}    ${ETCD_name}
    #Wait Until Keyword Succeeds    ${timeout}    2s
    #...    Pods Do Not Exist By Label    ${ETCD_namespace}    ${ETCD_pod_label_key}    ${ETCD_name}
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Pods Are Ready By Label    ${namespace}    ${common_pod_label_key}    ${rwcore_pod_label_value}
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Pods Are Ready By Label    ${namespace}    ${common_pod_label_key}    ${ofagent_pod_label_value}
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Pods Are Ready By Label    ${namespace}    ${common_pod_label_key}    ${adapter_openolt_pod_label_value}

*** Keywords ***
Get ETCD Replica Count
    [Arguments]    ${namespace}
    [Documentation]    Get the number of configured ETCD nodes
    ${rc}    ${size}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get ${ETCD_resources} ${ETCD_name} -o jsonpath='{.status.replicas}'
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${size}

Scale ETCD
    [Arguments]    ${namespace}    ${size}
    [Documentation]    Scale down the number of ETCD pod
    ${rc}=    Run and Return Rc
    ...    kubectl -n ${namespace} patch ${ETCD_resources} ${ETCD_name} -p '{"spec":{"replicas": ${size}}}'
    Should Be Equal As Integers    ${rc}    0

Validate ETCD Size
    [Arguments]    ${namespace}    ${ETCD_cluster_size}
    [Documentation]    Scale down the number of ETCD pod
    ${rc}    ${size}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get ${ETCD_resources} ${ETCD_name} -o jsonpath='{.status.replicas}'
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${size}    ${ETCD_cluster_size}    Unexpected number of replicas
    ${rc}    ${size}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get ${ETCD_resources} ${ETCD_name} -o jsonpath='{.status.readyReplicas}'
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${size}    ${ETCD_cluster_size}    Unexpected number of ready replicas
