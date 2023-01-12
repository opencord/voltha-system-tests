# Copyright 2017-2023 Open Networking Foundation (ONF) and the ONF Contributors
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
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Lookup Service IP
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Uses kubectl to resolve a service name to an IP
    ${rc}    ${ip}=    Run and Return Rc and Output
    ...    kubectl get svc -n ${namespace} ${name} -o jsonpath={.spec.clusterIP}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${ip}

Lookup Service PORT
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Uses kubectl to resolve a service name to an PORT
    ${rc}    ${port}=    Run and Return Rc and Output
    ...    kubectl get svc -n ${namespace} ${name} -o jsonpath={.spec.ports[0].port}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${port}

Restart Pod By Label
    [Arguments]    ${namespace}    ${label_key}   ${label_value}
    [Documentation]    Uses kubectl to force delete pod(s)
    ${rc}    ${restart_pod_name}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} -l ${label_key}=${label_value} --no-headers | awk '{print $1}'
    Log    ${restart_pod_name}
    Should Not Be Empty    ${restart_pod_name}    Unable to parse pod name
    @{pods}=    Split String    ${restart_pod_name}    separator=${\n}
    FOR    ${pod_name}    IN      @{pods}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    kubectl delete pod ${pod_name} -n ${namespace} --grace-period=0 --force
        Log    ${output}
    END

Exec Pod
    [Arguments]    ${namespace}    ${name}    ${command}
    [Documentation]    Uses kubectl to execute a command in the pod and return the output
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get pods -l app=${name} -o name
    Log    ${exec_pod_name}
    Should Not Be Empty    ${exec_pod_name}    Unable to parse pod name
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    kubectl exec -i ${exec_pod_name} -n ${namespace} -- ${command}
    Log    ${output}
    [return]    ${output}

Exec Pod In Kube
    [Arguments]    ${namespace}    ${name}    ${command}    ${grep}=${EMPTY}
    [Documentation]    Uses kubectl to execute a command in the pod and return the output
    ${rc}    ${exec_pod_name}=    Run Keyword If     '${grep}'=='${EMPTY}'
    ...    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get pods -l app.kubernetes.io/name=${name} -o name | awk 'NR==1{print $1}'
    ...    ELSE    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get pods -l app.kubernetes.io/name=${name} -o name \| grep ${grep}
    Log    ${exec_pod_name}
    Should Not Be Empty    ${exec_pod_name}    Unable to parse pod name
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    kubectl exec -i ${exec_pod_name} -n ${namespace} -- ${command}
    Log    ${output}
    [return]    ${output}

Exec Pod And Return Output And RC
    [Arguments]    ${namespace}    ${name}    ${command}
    [Documentation]    Uses kubectl to execute a command in the pod and return the output
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} | grep ${name} | awk 'NR==1{print $1}'
    Log    ${exec_pod_name}
    Should Not Be Empty    ${exec_pod_name}    Unable to parse pod name
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    kubectl exec -i ${exec_pod_name} -n ${namespace} -- ${command}
    Log    ${output}
    [return]    ${output}   ${rc}

Exec Pod Separate Stderr
    [Arguments]    ${namespace}    ${name}    ${command}
    [Documentation]    Uses kubectl to execute a command in the pod and return the stderr and stdout
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get pods -l app=${name} -o name
    Log    ${exec_pod_name}
    Should Not Be Empty    ${exec_pod_name}    Unable to parse pod name
    @{args}=     Split String    ${command}
    ${result}=    Run Process
    ...    kubectl     exec     -i     ${exec_pod_name}     -n     ${namespace}     --     @{args}
    ${stdout}=    Set Variable    ${result.stdout}
    ${stderr}=    Set Variable    ${result.stderr}
    Log    ${stdout}
    Log    ${stderr}
    [return]    ${stdout}    ${stderr}

Copy File To Pod
    [Arguments]    ${namespace}    ${label}    ${src}    ${dest}
    [Documentation]    Uses kubectl to copy a file to a pod
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} -l ${label} --no-headers | awk 'NR==1{print $1}'
    Log    ${exec_pod_name}
    Should Not Be Empty    ${exec_pod_name}    Unable to parse pod name
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    kubectl cp -n ${namespace} ${src} ${exec_pod_name}:${dest}
    Log    ${output}
    [return]    ${output}

Copy File From Pod
    [Arguments]    ${namespace}    ${label}    ${src}    ${dest}
    [Documentation]    Uses kubectl to copy a file from a pod
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} -l ${label} --no-headers | awk 'NR==1{print $1}'
    Log    ${exec_pod_name}
    Should Not Be Empty    ${exec_pod_name}    Unable to parse pod name
    ${rc}    ${output}=     Run and Return Rc and Output
    ...     kubectl cp -n ${namespace} ${exec_pod_name}:${src} ${dest}
    Log    ${output}
    [return]    ${output}

Apply Kubernetes Resources
    [Arguments]    ${resource_yaml}    ${namespace}
    [Documentation]    Use kubectl to create resources given a yaml file
    ${rc}    Run and Return Rc
    ...    kubectl apply -n ${namespace} -f ${resource_yaml}
    Should Be Equal as Integers    ${rc}    0

Delete Kubernetes Resources
    [Arguments]    ${resource_yaml}    ${namespace}
    [Documentation]    Use kubectl to delete resources given a yaml file
    ${rc}    Run and Return Rc
    ...    kubectl delete -n ${namespace} -f ${resource_yaml}
    Should Be Equal as Integers    ${rc}    0

Validate Pod Status
    [Arguments]    ${pod_name}    ${namespace}   ${expectedStatus}
    [Documentation]    To run the kubectl command and check the status of the given pod matches the expected status
    ${length}=    Run    kubectl get pod -n ${namespace} -o name | wc -l
    ${matched}=    Set Variable    False
    FOR    ${index}    IN RANGE    ${length}
        ${currentPodName}=    Run
        ...    kubectl get pod -n ${namespace} -o=jsonpath="{.items[${index}].status.containerStatuses[0].name}"
        Log    Required Pod : ${pod_name}
        Log    Current Pod: ${currentPodName}
        ${matched}=    Set Variable If    '${currentPodName}'=='${pod_name}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No pod ${podname} found
    ${currentStatusofPod}=    Run
    ...    kubectl get pod -n ${namespace} -o=jsonpath="{.items[${index}].status.phase}"
    Log    ${currentStatusofPod}
    Should Contain    ${currentStatusofPod}    ${expectedStatus}

Get Pod Name By Label
    [Arguments]    ${namespace}    ${label_key}   ${label_value}
    [Documentation]  Return a pod name from a given label
    ${rc}    ${pod_name}=    Run and Return Rc and Output
        ...    kubectl get pods -n ${namespace} -l ${label_key}=${label_value} --no-headers | awk '{print $1}'
    Should Not Be Empty    ${pod_name}    Pod not found
    [return]  ${pod_name}

Validate Pods Status By Label
    [Arguments]    ${namespace}    ${label_key}   ${label_value}    ${expectedStatus}
    [Documentation]    To run the kubectl command and check the status of all pods filter
    ...    by label matche the expected status
    ${command}=    Catenate
    ...    kubectl -n ${namespace} get pods -l ${label_key}=${label_value}
    ...    -o=jsonpath="{.items[?(.status.phase=='${expectedStatus}')].status.phase}"
    ${pods_status}=    Run    ${command}
    Should Not Be Equal    ${pods_status}    ${EMPTY}    Can't filter out Pods with exptected status ${expectedStatus}

Validate Pods Status By Name
    [Arguments]    ${namespace}    ${name}    ${expectedStatus}
    [Documentation]    To run the kubectl command and check the status of all pods filter
    ...    by label matche the expected status
    ${command}=    Catenate
    ...    kubectl -n ${namespace} get pods ${name}
    ...    -o=jsonpath="{.status.phase}"
    ${pods_status}=    Run    ${command}
    Should Not Be Equal    ${pods_status}    ${EMPTY}    Can't filter out Pods with exptected status ${expectedStatus}

Verify All Voltha Pods For Any Error Logs
    [Arguments]    ${datetime}  ${namespace}
    [Documentation]    This keyword checks for the error occurence in the voltha pods
    &{errorPodDict}    Create Dictionary
    &{containerDict}    Get Container Dictionary    voltha
    FOR    ${podName}    IN    @{PODLIST1}
        ${containerName}    Get From Dictionary    ${containerDict}    ${podName}
        ${rc}    ${logOutput}    Run And Return Rc And Output
        ...    kubectl logs --timestamps -n ${namespace} --since-time=${datetime} ${containerName}
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${logOutput}'=='${EMPTY}'
        ...    Run Keywords    Log    No Log found in pod ${podName}
        ...    AND    Continue For Loop
        ${errorDict}    Check For Error Logs in Pod Type1 Given the Log Output    ${logOutput}
        ${returnStatusFlagList}    Get Dictionary Keys    ${errorDict}
        ${returnStatusFlag}    Get From List    ${returnStatusFlagList}    0
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${returnStatusFlag}'=='Nologfound'
        ...    Run Keywords    Log    No Error Log found in pod ${podName}
        ...    AND    Continue For Loop
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${returnStatusFlag}'=='UnexpectedErrorfound'
        ...    Run Keywords    Log    Unexpected Error Log found in pod ${podName}
        ...    AND    Set to Dictionary    ${errorPodDict}    ${podName}    ${errorDict}
    END
    FOR    ${podName}    IN    @{PODLIST2}
        ${containerName}    Get From Dictionary    ${containerDict}    ${podName}
        ${rc}    ${logOutput}    Run And Return Rc And Output
        ...    kubectl logs --timestamps -n ${namespace} --since-time=${datetime} ${containerName}
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${logOutput}'=='${EMPTY}'
        ...    Run Keywords    Log    No Log found in pod ${podName}
        ...    AND    Continue For Loop
        ${errorDict}    Check For Error Logs in Pod Type2 Given the Log Output    ${logOutput}
        ${returnStatusFlagList}    Get Dictionary Keys    ${errorDict}
        ${returnStatusFlag}    Get From List    ${returnStatusFlagList}    0
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${returnStatusFlag}'=='Nologfound'
        ...    Run Keywords    Log    No Error Log found in pod ${podName}
        ...    AND    Continue For Loop
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${returnStatusFlag}'=='UnexpectedErrorfound'
        ...    Run Keywords    Log    Unexpected Error Log found in pod ${podName}
        ...    AND    Set to Dictionary    ${errorPodDict}    ${podName}    ${errorDict}
    END
    Print to Console    Error Statement logged in the following pods : ${errorPodDict}
    [Return]    ${errorPodDict}

Check For Error Logs in Pod Type1 Given the Log Output
    [Arguments]    ${logOutput}    ${logLevel}=error    ${errorMessage}=${EMPTY}
    [Documentation]    Checks for error message in the particular list of pods
    Log    ${logOutput}
    ${linesContainingLog} =    Get Lines Matching Regexp    ${logOutput}    .*\s\${logLevel}.*    partial_match=true
    ${is_exec_status}    ${output}    Run Keyword And Ignore Error    Should Be Empty    ${linesContainingLog}
    ${returnStatusFlag}    Set Variable If    '${is_exec_status}'=='PASS'
    ...    Nologfound    '${is_exec_status}'=='FAIL'    Errorlogfound
    ${linesContainingError} =    Get Lines Matching Regexp
    ...    ${logOutput}    .*\s\${logLevel}.*${errorMessage}    partial_match=true
    ${is_exec_status}    ${output}    Run Keyword And Ignore Error    Should Be Empty    ${linesContainingError}
    ${returnStatusFlag}    Set Variable If    '${is_exec_status}'=='PASS'
    ...    UnexpectedErrorfound    '${is_exec_status}'=='FAIL'    MatchingErrorlogfound
    Log    {linesContainingError}
    &{errorDict}    Create Dictionary    ${returnStatusFlag}    ${linesContainingLog}
    [Return]    ${errorDict}

Check For Error Logs in Pod Type2 Given the Log Output
    [Arguments]    ${logOutput}    ${logLevel}=warn    ${errorMessage}=${EMPTY}
    [Documentation]    Checks for error message in the particular set of pods
    Log    ${logOutput}
    ${linesContainingLog} =    Get Lines Matching Regexp
    ...    ${logOutput}    .*?\s.*level.*${logLevel}.*    partial_match=true
    ${is_exec_status}    ${output}    Run Keyword And Ignore Error    Should Be Empty    ${linesContainingLog}
    ${returnStatusFlag}    Set Variable If    '${is_exec_status}'=='PASS'
    ...    Nologfound    '${is_exec_status}'=='FAIL'    Errorlogfound
    ${linesContainingError} =    Get Lines Matching Regexp
    ...    ${logOutput}    .*?\s.*level.*${logLevel}.*msg.*${errorMessage}    partial_match=true
    ${is_exec_status}    ${output}    Run Keyword And Ignore Error    Should Be Empty    ${linesContainingError}
    ${returnStatusFlag}    Set Variable If    '${is_exec_status}'=='PASS'
    ...    UnexpectedErrorfound    '${is_exec_status}'=='FAIL'    MatchingErrorlogfound
    Log    {linesContainingError}
    &{errorDict}    Create Dictionary    ${returnStatusFlag}    ${linesContainingLog}
    [Return]    ${errorDict}

Get Container Dictionary
    [Arguments]    ${namespace}
    [Documentation]    Creates a mapping for pod name and container name and returns the same
    &{containerDict}    Create Dictionary
    ${containerName}    Set Variable    ${EMPTY}
    ${podName}    Run    kubectl get deployment -n ${namespace} | awk 'NR>1 {print $1}'
    @{podNameList}=    Split To Lines    ${podName}
    Append To List    ${podNameList}    voltha-etcd-cluster    voltha-kafka    voltha-ro-core    voltha-zookeeper
    Log    ${podNameList}
    #Creatiing dictionary to correspond pod name and container name
    FOR    ${pod}    IN    @{podNameList}
        ${containerName}    Run    kubectl get pod -n ${namespace} | grep ${pod} | awk '{print $1}'
        &{containerDict}    Set To Dictionary    ${containerDict}    ${pod}    ${containerName}
    END
    Log    ${containerDict}
    [Return]    ${containerDict}

Validate Error For Given Pods
    [Arguments]    ${datetime}    ${podDict}    ${namespace}
    [Documentation]
    ...    This keyword is used to get the list of pods if there is any unexpected error
    ...    in a particular pod(s) given the time-${datetime} from which the log needs to
    ...    be analysed and the dictionary of pods and the error in the dictionary format
    ...    ${podDict] .
    ...
    ...    Usage: ${returnStatusFlag} Validate Error For Given Pods ${datetime} ${podDict}  ${namespace}
    ...
    ...    Arguments:
    ...
    ...    ${datetime} = time from which the log needs to be taken
    ...    ${podDict} = Key-value pair of the pod name and the error msg
    ...    ${namespace} = the namespace into which look for pods
    ...
    ...    Example: ${podDict} = Set Dictionary ${podDict} radius sample error message.
    ...
    ...    In case the radius pod log has any other error than the expected
    ...    error, then the podname will be returned
    ${podList} =    Get Dictionary Keys    ${podDict}
    FOR    ${podName}    IN    @{podList}
        ${containerName}    Get From Dictionary    ${containerDict}    ${podName}
        ${expectedError}    Get From Dictionary    ${podDict}    ${podName}
        ${rc}    ${logOutput}    Run And Return Rc And Output
        ...    kubectl logs --timestamps -n ${namespace} --since-time=${datetime} ${containerName}
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${logOutput}'=='${EMPTY}'
        ...    Run Keywords    Log    No Log found in pod ${podName}
        ...    AND    Continue For Loop
        ${returnStatusFlag}    Check For Error Logs in Pod Type1 Given the Log Output    ${logOutput}
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${returnStatusFlag}'=='Nologfound'
        ...    Run Keywords    Log    No Error Log found in pod ${podName}
        ...    AND    Continue For Loop
        Run Keyword And Ignore Error
        ...    Run Keyword If    '${returnStatusFlag}'=='UnexpectedErrorfound'
        ...    Run Keywords    Log    Unexpected Error Log found in pod ${podName}
        ...    AND    Append To List    ${errorPodList}    ${podName}
    END
    [Return]    ${errorPodList}

Delete K8s Pod
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Uses kubectl to delete a named POD
    ${rc}    Run and Return Rc
    ...    kubectl delete -n ${namespace} pod/${name}
    Should Be Equal as Integers    ${rc}    0

Delete K8s Pods By Label
    [Arguments]    ${namespace}    ${key}    ${value}
    [Documentation]    Uses kubectl to delete a PODs, filtering by label
    ${rc}=    Run and Return Rc
    ...    kubectl -n ${namespace} delete pods -l${key}=${value}
    Should Be Equal as Integers    ${rc}    0

Delete K8s Pods By Name
    [Arguments]    ${namespace}    ${value}
    [Documentation]    Uses kubectl to delete a PODs, filtering by label
    ${rc}=    Run and Return Rc
    ...    kubectl -n ${namespace} delete pods ${value}
    Should Be Equal as Integers    ${rc}    0

Scale K8s Deployment
    [Arguments]    ${namespace}    ${name}    ${count}
    [Documentation]    Uses kubectl to scale a named deployment
    ${rc}    Run and Return Rc
    ...    kubectl scale --replicas=${count} -n ${namespace} deploy/${name}
    Should Be Equal as Integers    ${rc}    0

Get K8s Deployment by Pod Label
    [Arguments]    ${namespace}    ${key}    ${value}
    [Documentation]    Uses kubectl to scale a deployment given the app name of the pod
    ${rc}    ${name}    Run And Return Rc And Output
    ...    kubectl describe rs -n ${namespace} -l ${key}=${value} | grep "Controlled By" | awk -F'/' '{print $2}' | awk 'FNR == 1'
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${name}

Scale K8s Deployment by Pod Label
    [Arguments]    ${namespace}    ${key}    ${value}    ${count}
    [Documentation]    Uses kubectl to scale a deployment given the app name of the pod
    ${name}    Get K8s Deployment by Pod Label    ${namespace}    ${key}    ${value}
    Scale K8s Deployment    ${namespace}    ${name}    ${count}

Pod Exists
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Succeeds it the named POD exists
    ${rc}    ${count}    Run and Return Rc
    ...    kubectl get -n ${namespace} pod -o json | jq -r ".items[].metadata.name" | grep ${name}
    Should Be True    ${count}>0    Pod ${name} not found

Pod Does Not Exist
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Succeeds if the named POD does not exist
    ${rc}    ${count}    Run and Return Rc And Output
    ...    kubectl get -n ${namespace} pod -o json | jq -r ".items[].metadata.name" | grep -c ${name}
    Should Be Equal As Integers    ${count}    0
    Should Be True    ${count}==0    Pod ${name} exists but should not

Wait For Pods Not Exist
    [Arguments]    ${namespace}    ${list_names}
    [Documentation]    Checks the passed PODs are no longer existing
    FOR    ${pod_name}    IN    @{list_names}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
        ...    Pod Does Not Exist    ${namespace}    ${pod_name}
    END

Pods Do Not Exist By Label
    [Arguments]    ${namespace}    ${key}    ${value}
    [Documentation]    Succeeds if the named POD does not exist
    ${rc}    ${count}    Run and Return Rc And Output
    ...    kubectl get -n ${namespace} pod -l${key}=${value} -o json | jq -r ".items[].metadata.name" | wc -l
    Should Be Equal As Integers    ${count}    0
    Should Be True    ${count}==0    Pod with label ${key}=${value} exists but should not

Get Available Deployment Replicas
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Succeeds if the named POD exists and has a ready count > 0
    ${rc}    ${count}    Run and Return Rc and Output
    ...    kubectl get -n ${namespace} deploy/${name} -o jsonpath='{.status.availableReplicas}'
    ${result}=    Run Keyword If    '${count}' == ''    Set Variable    0
    ...    ELSE    Set Variable    ${count}
    [Return]    ${result}

Check Expected Available Deployment Replicas By Pod Label
    [Arguments]    ${namespace}    ${key}    ${value}    ${expected}
    [Documentation]    Succeeds if the named deployment has the expected number of available replicas
    ${name}    Get K8s Deployment by Pod Label    ${namespace}    ${key}    ${value}
    Check Expected Available Deployment Replicas    ${namespace}    ${name}    ${expected}

Check Expected Available Deployment Replicas
    [Arguments]    ${namespace}    ${name}    ${expected}
    [Documentation]    Succeeds if the named deployment has the expected number of available replicas
    ${count}=    Get Available Deployment Replicas    ${namespace}    ${name}
    Should Be Equal As Integers    ${expected}    ${count}

Get Deployment Replica Count
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Uses kubectl to fetch the number of configured replicas on a deployment
    ${rc}    ${value}    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get deploy/${name} -o 'jsonpath={.status.replicas}'
    Should Be Equal as Integers    ${rc}    0
    ${replicas}=    Run Keyword If    '${value}' == ''    Set Variable    0
    ...    ELSE    Set Variable    ${value}
    [Return]    ${replicas}

Does Deployment Have Replicas
    [Arguments]    ${namespace}    ${name}    ${expected_count}
    [Documentation]    Uses kubectl to fetch the number of configured replicas on a deployment
    ${rc}    ${value}    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get deploy/${name} -o 'jsonpath={.status.replicas}'
    Should Be Equal as Integers    ${rc}    0
    ${replicas}=    Run Keyword If    '${value}' == ''    Set Variable    0
    ...    ELSE    Set Variable    ${value}
    Should be Equal as Integers    ${replicas}    ${expected_count}

Pods Are Ready By Label
    [Arguments]    ${namespace}    ${key}    ${value}
    [Documentation]    Check that all pods with a label are ready
    ${pod_names}=    Get Pod Name By Label    ${namespace}    ${key}    ${value}
    Should Not Be Empty    ${pod_names}    Unable to parse pod name
    @{pods}=    Split String    ${pod_names}    separator=${\n}
    ${lenght}=    Get Length    ${pods}
    FOR    ${I}    IN RANGE    0    ${lenght}
        ${output}=    Run
        ...    kubectl -n ${namespace} get pods -l ${key}=${value} -o=jsonpath="{.items[${I}].status.containerStatuses[].ready}"
        Should Not Contain    ${output}    false
    END

Wait For Pods Ready
    [Arguments]    ${namespace}    ${list_apps}
    [Documentation]    Checks the passed PODs are ready
    FOR    ${app_name}    IN    @{list_apps}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
        ...    Pods Are Ready By Label    ${namespace}    app    ${app_name}
    END

Get Pod Ready Timestamp by Label
    [Arguments]    ${namespace}    ${key}    ${value}
    [Documentation]    delivers timestamp of pod was ready
    ${cmd}=    Catenate    kubectl -n ${namespace} get pods -l ${key}=${value} -o=json | jq -r
    ...    ".items[].status.containerStatuses[].state.running.startedAt"
    ${output}=    Run   ${cmd}
    [Return]    ${output}

Check Expected Running Pods Number By Label
    [Arguments]    ${namespace}    ${key}    ${value}    ${number}
    [Documentation]    Succeeds if the desired pod has expected number replicas
    ${rc}    ${count}    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get pods -l ${key}=${value} -o json | jq -r ".items[].status.phase" | wc -l
    Should Be Equal as Integers    ${count}    ${number}

Get Number of Running Pods Number By Label
    [Arguments]    ${namespace}    ${key}    ${value}
    [Documentation]   Returns the number of pods for a given label
    ${rc}    ${count}    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get pods -l ${key}=${value} -o name | wc -l
    [Return]    ${count}

Get Pod Restart Count
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Returns the restart count for the given Pod
    ${rc}    ${count}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} | grep ${name} | awk 'NR==1{print $4}'
    [Return]    ${count}

Get Pod Age
    [Arguments]    ${namespace}    ${name}
    [Documentation]    Returns the age for the given Pod
    ${rc}    ${age}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} | grep ${name} | awk 'NR==1{print $5}'
    [Return]    ${age}

Verify ONOS Pod Restart
    [Arguments]    ${restarted}=True
    [Documentation]    Verifies if any of the given ONOS instances restarted
    ${num_onos}=    Wait Until Keyword Succeeds    20s    5s    Get Number of Running Pods Number By Label    default
    ...    app    onos-onos-classic
    FOR    ${I}    IN RANGE    0    ${num_onos}
         ${onos_pod}=    Catenate    SEPARATOR=-    onos-onos-classic    ${I}
         ${count}=    Get Pod Restart Count    default    ${onos_pod}
         Run Keyword If    ${restarted}
         ...    Should Not Be Equal As Integers    ${count}    0    ONOS Pod ${onos_pod} Not Restarted
         ...    ELSE
         ...    Should Be Equal As Integers    ${count}    0    ONOS Pod ${onos_pod} Restarted
    END

Deploy Pod New Image
    [Arguments]    ${namespace}    ${deployment}    ${container}    ${image}
    [Documentation]   Deploys the Pod given image
    ${rc}    Run and Return Rc
    ...    kubectl -n ${namespace} set image deployment/${deployment} ${container}=${image}
    Should Be Equal as Integers    ${rc}    0

Verify Pod Image
    [Arguments]    ${namespace}    ${key}    ${value}    ${image}
    [Documentation]    Verifies the Pod Image
    ${output}=    Run
    ...    kubectl -n ${namespace} get pods -l ${key}=${value} -o=jsonpath="{.items[*].spec.containers[*].image}"
    Should Be Equal    '${output}'    '${image}'

Get Pod Image And App Version And Helm Chart By Label
    [Arguments]    ${namespace}    ${key}    ${value}
    [Documentation]    Retrieves Pod Image and, App and Helm Chart Version details
    ${image}=    Run
    ...    kubectl -n ${namespace} get pods -l ${key}=${value} -o=jsonpath="{.items[*].spec.containers[*].image}"
    ${cmd}=    Catenate    SEPARATOR=
    ...    kubectl -n ${namespace} get pods -l ${key}=${value} -o=
    ...    jsonpath="{.items[*].metadata.labels.\\app\\.kubernetes\\.io\\/version}"
    ${app_version}=    Run    ${cmd}
    ${helm_chart}=    Run
    ...    kubectl -n ${namespace} get pods -l ${key}=${value} -o=jsonpath="{.items[*].metadata.labels.\\helm\\.sh\\/chart}"
    [Return]    ${image}    ${app_version}    ${helm_chart}
