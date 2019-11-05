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
Documentation     Provide the function to scale up/down the etcd cluster
Library           OperatingSystem

*** Variables ***
${timeout}        60s
${desired_etcd_cluster_size}        3
${minimal_etcd_cluster_size}        2
${namespace}        voltha
${etcd__resources}        etcdclusters.etcd.database.coreos.com
${etcd_name}       voltha-etcd-cluster

*** Test Cases ***
Scale Down etcd Cluster
    [Documentation]    Scale Down the etcd cluster to minimal size, skip test if current cluster size < 3
    [Tags]    scaledown
    ${current_size}=   Get etcd Running Size    voltha
    Pass Execution If    '${current_size}' != '${desired_etcd_cluster_size}'
    ...    'Skip the test if the cluster size smaller than minimal size 3'
    # The minimal cluster size after scale down
    # based on https://github.com/etcd-io/etcd/blob/master/Documentation/faq.md#what-is-failure-tolerance
    Scale etcd    ${namespace}    ${minimal_etcd_cluster_size}
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate etcd Size   ${namespace}    ${minimal_etcd_cluster_size}

Scale Up etcd Cluster
    [Documentation]    Recover the etcd cluster by scaling up its size
    [Tags]    scaleup
    ${current_size}=   Get etcd Running Size    voltha
    Pass Execution If    '${current_size}' != '${minimal_etcd_cluster_size}'
    ...    'Skip the test if the cluster size smaller than minimal size 3'
    Scale etcd    ${namespace}    ${desired_etcd_cluster_size}
    # We scale up the size to 3, the recommended size of etcd cluster.
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate etcd Size   ${namespace}    ${desired_etcd_cluster_size}

*** Keywords ***
Get etcd Running Size
    [Arguments]    ${namespace}
    [Documentation]    Get the number of running etcd nodes
    ${rc}    ${size}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get ${etcd__resources} ${etcd_name} -o jsonpath='{.status.size}'
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${size}

Scale etcd
    [Arguments]    ${namespace}    ${size}
    [Documentation]    Scale down the number of etcd pod
    ${rc}=    Run and Return Rc
    ...    kubectl -n ${namespace} patch ${etcd__resources} ${etcd_name} --type='merge' -p '{"spec":{"size":${size}}}'
    Should Be Equal As Integers    ${rc}    0

Validate etcd Size
    [Arguments]    ${namespace}    ${etcd_cluster_size}
    [Documentation]    Scale down the number of etcd pod
    ${rc}    ${size}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get ${etcd__resources} ${etcd_name} -o jsonpath='{.status.size}'
    Should Be Equal As Integers    ${size}    ${etcd_cluster_size}
