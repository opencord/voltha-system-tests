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

# voltctl common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           HttpLibrary.HTTP
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Lookup Service IP
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Uses kubeclt to resolve a service name to an IP
    ${rc}    ${ip}=    Run and Return Rc and Output
    ...    kubectl get svc -n ${namespace} ${name} -o jsonpath={.spec.clusterIP}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${ip}

Lookup Service PORT
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Uses kubeclt to resolve a service name to an PORT
    ${rc}    ${port}=    Run and Return Rc and Output
    ...    kubectl get svc -n ${namespace} ${name} -o jsonpath={.spec.ports[0].port}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${port}

Verify All Voltha Pods For Any Error Logs
    [Arguments]    ${datetime}
    [Documentation]   This keyword checks for the error occurence in the voltha pods
    @{errorPodList}   Create List
    &{containerDict}    Get Container Dictionary
    FOR   ${podName}  IN   @{PODLIST1}
    \   ${containerName}   Get From Dictionary  ${containerDict}    ${podName}
    \   ${rc}   ${logOutput}    Run And Return Rc And Output   ${KUBECTL_CONFIG};kubectl logs --timestamps -n voltha --since-time=${datetime} ${containerName}
    \   Run Keyword And Ignore Error  Run Keyword If   '${logOutput}'=='${EMPTY}'    Run Keywords  Log  No Log found in pod ${podName}  AND   Continue For Loop
    \   ${returnStatusFlag}    Check For Error Logs in Pod Type1 Given the Log Output     ${logOutput}
    \   Run Keyword And Ignore Error   Run Keyword If    '${returnStatusFlag}'=='Nologfound'  Run Keywords  Log   No Error Log found in pod ${podName}  AND   Continue For Loop
    \   Run Keyword And Ignore Error   Run Keyword If    '${returnStatusFlag}'=='UnexpectedErrorfound'   Run Keywords  Log   Unexpected Error Log found in pod ${podName}  AND   Append To List    ${errorPodList}   ${podName}
    FOR   ${podName}  IN   @{PODLIST2}
    \   ${containerName}   Get From Dictionary  ${containerDict}    ${podName}
    \   ${rc}   ${logOutput}   Run And Return Rc And Output    ${KUBECTL_CONFIG};kubectl logs --timestamps -n voltha --since-time=${datetime} ${containerName}
    \   Run Keyword And Ignore Error   Run Keyword If   '${logOutput}'=='${EMPTY}'   Run Keywords   Log   No Log found in pod ${podName}  AND    Continue For Loop
    \   ${returnStatusFlag}    Check For Error Logs in Pod Type2 Given the Log Output     ${logOutput}
    \   Run Keyword And Ignore Error   Run Keyword If    '${returnStatusFlag}'=='Nologfound'  Run Keywords  Log   No Error Log found in pod ${podName}  AND   Continue For Loop
    \   Run Keyword And Ignore Error   Run Keyword If    '${returnStatusFlag}'=='UnexpectedErrorfound'   Run Keywords  Log   Unexpected Error Log found in pod ${podName}  AND  Append To List    ${errorPodList}   ${podName}
    [Return]    ${errorPodList}


Check For Error Logs in Pod Type1 Given the Log Output
    [Arguments]    ${logOutput}    ${logLevel}=error   ${errorMessage}=${EMPTY}
    Log    ${logOutput}
    ${linesContainingLog} =      Get Lines Matching Regexp       ${logOutput}     .*\s\${logLevel}.*    partial_match=true
    ${is_exec_status}   ${output}   Run Keyword And Ignore Error        Should Be Empty         ${linesContainingLog}
    ${returnStatusFlag}   Set Variable If       '${is_exec_status}'=='PASS'      Nologfound  '${is_exec_status}'=='FAIL'          Errorlogfound
    ${linesContainingError} =      Get Lines Matching Regexp       ${logOutput}     .*\s\${logLevel}.*${errorMessage}   partial_match=true
    ${is_exec_status}   ${output}   Run Keyword And Ignore Error        Should Be Empty         ${linesContainingError}
    ${returnStatusFlag}   Set Variable If       '${is_exec_status}'=='PASS'      UnexpectedErrorfound   '${is_exec_status}'=='FAIL'     MatchingErrorlogfound
    Log   {linesContainingError}
    [Return]     ${returnStatusFlag}

Check For Error Logs in Pod Type2 Given the Log Output
    [Arguments]    ${logOutput}    ${logLevel}=warn   ${errorMessage}=${EMPTY}
    Log    ${logOutput}
    ${linesContainingLog} =      Get Lines Matching Regexp       ${logOutput}    .*?\s.*level.*${logLevel}.*  partial_match=true
    ${is_exec_status}   ${output}       Run Keyword And Ignore Error    Should Be Empty         ${linesContainingLog}
    ${returnStatusFlag}   Set Variable If       '${is_exec_status}'=='PASS'      Nologfound  '${is_exec_status}'=='FAIL'          Errorlogfound
    ${linesContainingError} =      Get Lines Matching Regexp       ${logOutput}    .*?\s.*level.*${logLevel}.*msg.*${errorMessage}   partial_match=true
    ${is_exec_status}    ${output}   Run Keyword And Ignore Error       Should Be Empty         ${linesContainingError}
    ${returnStatusFlag}   Set Variable If       '${is_exec_status}'=='PASS'      UnexpectedErrorfound   '${is_exec_status}'=='FAIL'     MatchingErrorlogfound
    Log   {linesContainingError}
    [Return]     ${returnStatusFlag}

Get Container Dictionary
    &{containerDict}     Create Dictionary
    ${containerName}    Set Variable   ${EMPTY}
    ${podName}   Run     ${KUBECTL_CONFIG};kubectl get deployment -n voltha | awk 'NR>1 {print $1}'
    @{podNameList}=     Split To Lines    ${podName}
    Append To List    ${podNameList}    voltha-etcd-cluster   voltha-kafka   voltha-ro-core   voltha-zookeeper
    Log    ${podNameList}
#Creatiing dictionary to correspond pod name and container name
    FOR   ${pod}    IN    @{podNameList}
    \    ${containerName}   Run    ${KUBECTL_CONFIG};kubectl get pod -n voltha | grep ${pod} | awk '{print $1}'
    \    &{containerDict}   Set To Dictionary    ${containerDict}     ${pod}    ${containerName}
    Log   ${containerDict}
    [Return]    ${containerDict}


Validate Error For Given Pods
    [Arguments]    ${datetime}   ${podDict}
    [Documentation]    This keyword is used to get the list of pods if there is any unexpected error in a particular pod(s) given the time-${datetime} from which the log needs to be analysed and the dictionary of pods and the error in the dictionary format ${podDict] .\n\n Usage : ${returnStatusFlag}   Validate Error For Given Pods   ${datetime}   ${podDict}  \n where, \n ${datetime} = time from which the log needs to be taken \n ${podDict} = Key-value pair of the pod name and the error  msg expected like ${podDict} = Set Dictionary    ${podDict}   radius     sample error message. \n\n In case the radius pod log has any other error than the expected error, then the podname will be returned
    ${podList} =	Get Dictionary Keys	  ${podDict}	
    FOR   ${podName}  IN   @{podList}
    \   ${containerName}   Get From Dictionary  ${containerDict}    ${podName}
	\   ${expectedError}   Get From Dictionary  ${podDict}    ${podName}	
    \   ${rc}   ${logOutput}    Run And Return Rc And Output   ${KUBECTL_CONFIG};kubectl logs --timestamps -n voltha --since-time=${datetime} ${containerName}
    \   Run Keyword And Ignore Error  Run Keyword If   '${logOutput}'=='${EMPTY}'    Run Keywords  Log  No Log found in pod ${podName}  AND   Continue For Loop
    \   ${returnStatusFlag}    Check For Error Logs in Pod Type1 Given the Log Output     ${logOutput}   
    \   Run Keyword And Ignore Error   Run Keyword If    '${returnStatusFlag}'=='Nologfound'  Run Keywords  Log   No Error Log found in pod ${podName}  AND   Continue For Loop
    \   Run Keyword And Ignore Error   Run Keyword If    '${returnStatusFlag}'=='UnexpectedErrorfound'   Run Keywords  Log   Unexpected Error Log found in pod ${podName}  AND  Append To List    ${errorPodList}   ${podName}
    [Return]    ${errorPodList}
