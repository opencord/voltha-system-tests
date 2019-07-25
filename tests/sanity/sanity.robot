# Copyright 2017-present Open Networking Foundation
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
Documentation     Creates bbsim olt/onu and validates activataion
...               Assumes voltha-go, go-based onu/olt adapters, and bbsim are installed
...               voltctl and kubectl should be configured prior to running these tests
Library           OperatingSystem
Resource          ${CURDIR}../../libraries/utils.robot
Resource          ${CURDIR}../../variables/variables.robot

*** Test Cases ***
Activate Device BBSIM OLT/ONU
    [Documentation]    Validate deployment ->
    ..    create and enable bbsim device ->
    ..    re-validate deployment
    [Tags]    activate
    #validate system deployment
    Validate System Stable
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output    voltctl device create -t openolt -H ${BBSIM_SERVICE}:${BBSIM_PORT}
    Should Be Equal As Integers    ${rc}    0
    #enable device
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl device enable ${device_id}
    Should Be Equal As Integers    ${rc}    0
    #validate olt states
    Wait Until Keyword Succeeds    10s    5s    Validate Device    ${BBSIM_OLT_SN}    ENABLED    ACTIVE    REACHABLE
    #validate onu states
    Wait Until Keyword Succeeds    10s    5s    Validate Device    ${BBSIM_ONU_SN}    ENABLED    ACTIVE    REACHABLE
    #re-validate system deployment
    Validate System Stable

Check EAPOL Flows in ONOS
    [Documentation]    Validates eapol flows for the onu are pushed from voltha
    [Tags]    notready

Validate ONU Authenticated in ONOS
    [Documentation]    Validates onu is AUTHORIZED in ONOS as bbsim will attempt to authenticate
    [Tags]    notready

Provision ONU Subscriber in ONOS
    [Documentation]    Through the olt-app in ONOS, execute 'volt-add-subscriber-access' and validate IP Flows
    [Tags]    notready

Validate DHCP Assignment in ONOS
    [Documentation]    After IP Flows are pushed to the device, BBSIM will start a dhclient for the ONU.
    [Tags]    notready

*** Keywords ***
Validate System Stable
    [Documentation]    Validates that all the expected helm-charts are in DEPLOYED status.
    [Tags]    voltha-0001
    : FOR    ${i}    IN    @{charts}
    \    ${rc}=    Run and Return Rc    helm list | grep ${i} | grep -i deployed;
    \    Should Be Equal As Integers    ${rc}    0
    ${deployed_nodes}=    Run    kubectl get nodes -o json
    Log    ${deployed_nodes}
    @{nodes}=    Get Names    ${deployed_nodes}
    Log    ${nodes}
    #validates that all expected nodes to be running
    : FOR    ${i}    IN    @{nodes}
    \    List Should Contain Value    ${nodes}    ${i}
    : FOR    ${i}    IN    @{nodes}
    \    ${status}=     Run    kubectl get nodes ${i} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
    \    ${pidpressure}=     Run    kubectl get nodes ${i} -o jsonpath='{.status.conditions[?(@.type=="PIDPressure")].status}'
    \    ${memorypressure}=     Run    kubectl get nodes ${i} -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].status}'
    \    ${diskpressure}=     Run    kubectl get nodes ${i} -o jsonpath='{.status.conditions[?(@.type=="DiskPressure")].status}'
    \    Should Be Equal    ${status}    True
    \    Should Be Equal    ${pidpressure}    False
    \    Should Be Equal    ${memorypressure}    False
    \    Should Be Equal    ${diskpressure}    False
    Run Keyword and Continue on Failure    Validate Pods
    Validate Deployments    ${deployments}
    ${voltha_services}=    Run    kubectl get services -o json -n voltha
    Log    ${voltha_services}
    @{voltha_services}=    Get Names    ${voltha_services}
    #validates that all expected services are running
    : FOR    ${i}    IN    @{services}
    \    Run Keyword and Continue on Failure    List Should Contain Value    ${voltha_services}    ${i}

Get Names
    [Documentation]    Gets names of K8 resources running
    [Arguments]    ${output}
    @{names}=    Create List
    ${output}=    To JSON    ${output}
    ${len}=    Get Length    ${output}
    ${length}=    Get Length    ${output['items']}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${item}=    Get From List    ${output['items']}    ${INDEX}
    \    ${metadata}=    Get From Dictionary    ${item}    metadata
    \    ${name}=    Get From Dictionary    ${metadata}    name
    \    Append To List    ${names}    ${name}
    [Return]    @{names}

Validate Pods
    [Documentation]    Expected pods should be healthy and running
    @{container_names}=    Create List
    ${pods}=    Run    kubectl get pods -o json -n voltha
    Log    ${pods}
    ${pods}=    To JSON    ${pods}
    ${len}=    Get Length    ${pods}
    ${length}=    Get Length    ${pods['items']}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${item}=    Get From List    ${pods['items']}    ${INDEX}
    \    ${metadata}=    Get From Dictionary    ${item}    metadata
    \    ${name}=    Get From Dictionary    ${metadata}    name
    \    ${status}=    Get From Dictionary    ${item}    status
    \    ${containerStatuses}=    Get From Dictionary    ${status}    containerStatuses
    \    Log    ${containerStatuses}
    \    ${cstatus}=    Get From List    ${containerStatuses}    0
    \     Log    ${cstatus}
    \    ${container_name}=    Get From Dictionary    ${cstatus}    name
    \    ${state}=    Get From Dictionary    ${cstatus}    state
    \    Run Keyword and Continue On Failure    Should Contain    ${state}    running
    \    Run Keyword and Continue On Failure    Should Not Contain    ${state}    stopped
    \    Log    ${state}
    \    Append To List    ${container_names}    ${container_name}
    #validates that all expected containers to be running are in one of the pods inspected above
    : FOR    ${i}    IN    @{pods}
    \    Run Keyword and Continue on Failure    List Should Contain Value    ${container_names}    ${i}

Validate Deployments
    [Arguments]    ${expected_deployments}
    [Documentation]    Expected deployments should be successfully rolled out
    ${deplymts}=    Run    kubectl get deployments -o json -n voltha
    @{deplymts}=    Get Names    ${deplymts}
    : FOR    ${i}    IN    @{deplymts}
    \    ${rollout_status}=    Run    kubectl rollout status deployment/${i} -n voltha
    \    Run Keyword and Continue On Failure    Should Be Equal    ${rollout_status}    deployment "${i}" successfully rolled out
    \    ##validate replication sets
    \    ${desired}=    Run    kubectl get deployments ${i} -o jsonpath='{.status.replicas}'
    \    ${available}=    Run    kubectl get deployments ${i} -o jsonpath='{.status.availableReplicas}'
    \    Run Keyword and Continue On Failure    Should Be Equal    ${desired}    ${available}
    #validates that all expected deployments to exist
    : FOR    ${i}    IN    @{expected_deployments}
    \    Run Keyword and Continue On Failure    List Should Contain Value    ${deplymts}    ${i}