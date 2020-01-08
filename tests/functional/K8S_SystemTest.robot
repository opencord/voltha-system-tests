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
Library           OperatingSystem
Resource          ../../libraries/k8s.robot

*** Variables ***
${timeout}        60s
${desired_ETCD_cluster_size}        3
${minimal_ETCD_cluster_size}        2
${namespace}        voltha
${ETCD_resources}        etcdclusters.etcd.database.coreos.com
${ETCD_name}       voltha-etcd-cluster
${ETCD_pod_label_key}    etcd_cluster
${common_pod_label_key}    app
${rwcore_pod_label_value}    rw-core
${ofagent_pod_label_value}    ofagent
${adapter_openolt_pod_label_value}    adapter-open-olt

*** Test Cases ***
Scale Down ETCD Cluster
    [Documentation]    Scale Down the ETCD cluster to minimal size, skip test if current cluster size < 3
    [Tags]    scaledown    ETCDdown
    ${current_size}=   Get ETCD Running Size    voltha
    Pass Execution If    '${current_size}' != '${desired_ETCD_cluster_size}'
    ...    'Skip the test if the cluster size smaller than minimal size 3'
    # The minimal cluster size after scale down
    # based on https://github.com/ETCD-io/ETCD/blob/master/Documentation/faq.md#what-is-failure-tolerance
    Scale ETCD    ${namespace}    ${minimal_ETCD_cluster_size}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate ETCD Size   ${namespace}    ${minimal_ETCD_cluster_size}

Scale Up ETCD Cluster
    [Documentation]    Recover the ETCD cluster by scaling up its size
    [Tags]    scaleup    ETCDup
    ${current_size}=   Get ETCD Running Size    voltha
    Pass Execution If    '${current_size}' != '${minimal_ETCD_cluster_size}'
    ...    'Skip the test if the cluster size smaller than minimal size 3'
    Scale ETCD    ${namespace}    ${desired_ETCD_cluster_size}
    # We scale up the size to 3, the recommended size of ETCD cluster.
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate ETCD Size   ${namespace}    ${desired_ETCD_cluster_size}

ETCD Failure Test
    [Documentation]    Failure Scenario Test: ETCD Crash
    [Tags]    FailureTest
    Delete K8s Pods By Label    ${namespace}    ${ETCD_pod_label_key}    ${ETCD_name}
     Wait Until Keyword Succeeds    ${timeout}    2s
     ...    Pods Does Not Exist By Label   ${namespace}   ${ETCD_pod_label_key}    ${ETCD_name}
     Wait Until Keyword Succeeds    ${timeout}    2s
     ...    Pods Does Not Ready By Label   ${namespace}   ${common_pod_label_key}    ${rwcore_pod_label_value}
     Wait Until Keyword Succeeds    ${timeout}    2s
     ...    Pods Does Not Ready By Label   ${namespace}   ${common_pod_label_key}    ${ofagent_pod_label_value}
     Wait Until Keyword Succeeds    ${timeout}    2s
     ...    Pods Does Not Ready By Label   ${namespace}   ${common_pod_label_key}    ${adapter_openolt_pod_label_value}

*** Keywords ***
Get ETCD Running Size
    [Arguments]    ${namespace}
    [Documentation]    Get the number of running ETCD nodes
    ${rc}    ${size}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get ${ETCD_resources} ${ETCD_name} -o jsonpath='{.status.size}'
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${size}

Scale ETCD
    [Arguments]    ${namespace}    ${size}
    [Documentation]    Scale down the number of ETCD pod
    ${rc}=    Run and Return Rc
    ...    kubectl -n ${namespace} patch ${ETCD_resources} ${ETCD_name} --type='merge' -p '{"spec":{"size":${size}}}'
    Should Be Equal As Integers    ${rc}    0

Validate ETCD Size
    [Arguments]    ${namespace}    ${ETCD_cluster_size}
    [Documentation]    Scale down the number of ETCD pod
    ${rc}    ${size}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get ${ETCD_resources} ${ETCD_name} -o jsonpath='{.status.size}'
    Should Be Equal As Integers    ${size}    ${ETCD_cluster_size}
