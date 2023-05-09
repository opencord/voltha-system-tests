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
# onos common functions

*** Settings ***
Documentation     Library for BBSimCtl interactions
Resource          ./k8s.robot

*** Variables ***
&{IGMP_TASK_DICT}          join=0    leave=1    joinv3=2

*** Keywords ***
List ONUs
    [Documentation]  Lists ONUs via BBSimctl
    [Arguments]    ${namespace}    ${bbsim_pod_name}
    ${onus}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu list
    Log     ${onus}
    Should Be Equal as Integers    ${rc}    0

Restart Auth
    [Documentation]  Restart Authentication on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu auth_restart ${onu}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Restart DHCP
    [Documentation]  Restart Dhcp on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu dhcp_restart ${onu}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

List Service
    [Documentation]  Lists Service via BBSimctl
    [Arguments]    ${namespace}    ${bbsim_pod_name}
    ${service}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl service list
    Log     ${service}
    Should Be Equal as Integers    ${rc}    0

JoinOrLeave Igmp Rest Based
    [Documentation]  Joins or Leaves Igmp on a BBSim ONU (based on Rest Endpoint)
    [Arguments]    ${bbsim_rel_session}    ${onu}    ${uni}    ${task}    ${group_address}    ${vlan}=55
    ${resp}=    Post Request    ${bbsim_rel_session}
    ...    /v1/olt/onus/${onu}/${uni}/igmp/${IGMP_TASK_DICT}[${task}]/${group_address}/${vlan}
    Log    ${resp}

JoinOrLeave Igmp
    [Documentation]  Joins or Leaves Igmp on a BBSim ONU
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}    ${uni}    ${task}    ${group_address}    ${vlan}=55
    ${res}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu igmp ${onu} ${uni} ${task} ${group_address} -v ${vlan}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Power On ONU
    [Documentation]    This keyword turns on the power for onu device.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${result}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu poweron ${onu}
    Should Contain    ${result}    successfully    msg=Can not poweron ${onu}    values=False

Power Off ONU
    [Documentation]    This keyword turns off the power for onu device.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${result}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu shutdown ${onu}
    Should Contain    ${result}    successfully    msg=Can not shutdown ${onu}    values=False

Set Wrong MDS Counter ONU
    [Documentation]    This keyword sets wrong MDS counter for onu device.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${result}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu invalidate_mds ${onu}
    Should Be Equal as Integers    ${rc}    0
    Should Contain    ${result}    MDS counter of ONU    msg=Can not invalidate MDS counter ${onu}    values=False
    Should Contain    ${result}    , set to    msg=Can not invalidate MDS counter ${onu}    values=False

Get ONU Ponport Id
    [Documentation]    Retrieves ONU Ponport Id for the specified ONU device via BBSimctl.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${ponport_id}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu get ${onu} | awk 'NR==2 {print $1}'
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${ponport_id}

Get ONU Id
    [Documentation]    Retrieves ONU Id for the specified ONU device via BBSimctl.
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}
    ${onu_id}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu get ${onu} | awk 'NR==2 {print $2}'
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${onu_id}

Get ONUs List
    [Documentation]    Fetches ONUs via BBSimctl
    [Arguments]    ${namespace}    ${bbsim_pod_name}
    ${onus}    ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu list | awk 'NR>1 {print $3}'
    @{onuList}=    Split To Lines    ${onus}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${onuList}

Restart Grpc Server
    [Documentation]  Restart Grpc Server on a BBSim OLT
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${delay}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl olt restartServer ${delay}
    Log     ${res}
    Should Be Equal as Integers    ${rc}    0

Verify ONU Device Image On BBSim
    [Documentation]    Validates the state of ONU in case of Image Upgrade
    [Arguments]    ${namespace}    ${bbsim_pod_name}    ${onu}    ${internal_state}
    ${res}     ${rc}=    Exec Pod And Return Output And RC    ${namespace}    ${bbsim_pod_name}
    ...    bbsimctl onu list | grep ${onu} | awk '{print $5}'
    Should Be Equal as Integers    ${rc}    0
    Should Be Equal    ${res}    ${internal_state}

Get Images Count
    [Documentation]    Validates the state of ONU in case of Image Upgrade
    [Arguments]    ${webserver_port}=50074
    ${rc}    ${output}=    Run and Return Rc and Output    curl localhost:${webserver_port}/images-count 2>/dev/null
    Should Be Equal as Integers    ${rc}    0    Could not access images-count of bbsim
    ${value}=    Fetch From Right    ${output}    :
    ${count}=    Fetch From Left     ${value}    }
    [Return]    ${count}

Restart And Check BBSIM
    [Documentation]    This keyword restarts bbsim and waits for it to come up again
    ...    Following steps will be executed:
    ...    - restart bbsim adaptor
    ...    - check bbsim adaptor is ready again
    [Arguments]    ${namespace}
    ${bbsim_apps}   Create List    bbsim
    ${label_key}    Set Variable   app
    ${bbsim_label_value}    Set Variable   bbsim
    Restart Pod By Label    ${namespace}    ${label_key}    ${bbsim_label_value}
    Sleep    5s
    Wait For Pods Ready    ${namespace}    ${bbsim_apps}

Get BBSIM Svc and Webserver Port
    [Documentation]    This keyword gets bbsim instance and bbsim webserver port from image url
    @{words}=    Split String    ${image_url}    /
    ${SvcAndPort}    Set Variable     @{words}[2]
    ${bbsim_svc}    ${webserver_port}=    Split String    ${SvcAndPort}    :    1
    ${svc_return}    Set Variable If    '${bbsim_svc}'!='${EMPTY}'    ${bbsim_svc}    ${BBSIM_INSTANCE}
    ${port_return}   Set Variable If    '${webserver_port}'!='${EMPTY}'    ${webserver_port}    ${BBSIM_WEBSERVER_PORT}
    [Return]    ${svc_return}    ${port_return}

# keywords regarding OMCC message version

Get BBSIM OMCC Version
    [Documentation]    Retrieves OMCC Version from BBSIM
    [Arguments]    ${namespace}    ${instance}=0
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} | grep bbsim${instance} | awk 'NR==1{print $1}'
    Log    ${exec_pod_name}
    Should Not Be Empty    ${exec_pod_name}    Unable to parse pod name
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    kubectl -n ${namespace} get pods ${exec_pod_name} -o=jsonpath="{.spec.containers[].command}"
    Log    ${output}
    Should Be Equal as Integers    ${rc}    0
    Should Not Be Empty    ${output}    Unable to read OMCC Version
    ${output}=    Remove String    ${output}    "    [    ]
    ${is_comma_separated}=    Evaluate    "," in """${output}"""
    @{commands}=    Run Keyword If    ${is_comma_separated}    Split String    ${output}    ,
    ...             ELSE    Split String    ${output}
    ${length}=    Get Length    ${commands}
    ${match}=    Set Variable    False
    FOR    ${I}    IN RANGE    0    ${length}
        ${item}=    Get From List    ${commands}    ${I}
        ${match}=    Set Variable If    "${item}"=="-omccVersion"    True    ${match}
        ${omcc_version}=    Run Keyword If    ${match}    Get From List    ${commands}    ${I+1}
        Exit For Loop IF     ${match}
    END
    Should Be True    ${match}    Unable to read OMCC Version
    ${is_extended}=    Is OMCC Extended Version    ${omcc_version}
    [return]    ${omcc_version}    ${is_extended}

Is OMCC Extended Version
    [Documentation]    Checks passed value and return False (baseline) or True (extended)
    ...                baseline: 124-130, 160-163
    ...                extended: 150, 176-180
    [Arguments]    ${omcc_version}
    ${is_extended}=    Set Variable If    '${omcc_version}'=='150'    True
    ...      '${omcc_version}'>='176' and '${omcc_version}'<='180'    True
    ...                                                               False
    [return]    ${is_extended}

# Keywords regarding restart BBSIM by Helm Charts

Restart BBSIM by Helm Charts
    [Documentation]    Restart BBSIM by helm charts
    ...                Attention: config-yaml file has to pass by ${extra_helm_flags}!
    [Arguments]    ${namespace}    ${instance}=0    ${extra_helm_flags}=${EMPTY}
    Remove BBSIM Helm Charts    ${namespace}    ${instance}
    Restart BBSIM Helm Charts   ${namespace}    ${instance}    extra_helm_flags=${extra_helm_flags}
    Restart Port Forward BBSIM  ${namespace}    ${instance}

Remove BBSIM Helm Charts
    [Documentation]    Remove BBSIM helm charts
    [Arguments]    ${namespace}    ${instance}=0
    ${cmd}    Catenate    helm delete -n '${namespace}' 'bbsim${instance}'
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0
    ${list}    Create List    bbsim${instance}
    Wait For Pods Not Exist    ${namespace}    ${list}

Restart BBSIM Helm Charts
    [Documentation]    Restart BBSIM helm charts
    ...                Attention: config-yaml file has to pass by ${extra_helm_flags}!
    [Arguments]    ${namespace}    ${instance}=0    ${extra_helm_flags}=${EMPTY}
    ${cmd}    Catenate
    ...    helm upgrade --install -n ${namespace} bbsim${instance} onf/bbsim
    ...    --set olt_id=1${instance}
    ...    --set global.image_pullPolicy=Always
    ...    --set global.image_tag=master
    ...    --set global.image_org=voltha/
    ...    --set global.image_registry=
    ...    --set global.log_level=${helmloglevel} ${extra_helm_flags}
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0
    ${list}   Create List    bbsim
    Wait For Pods Ready    ${namespace}    ${list}

Restart Port Forward BBSIM
    [Documentation]    Restart Port forward BBSIM
    [Arguments]    ${namespace}    ${instance}=0
    ${tag}    Catenate    bbsim${instance}
    Restart VOLTHA Port Forward    ${tag}
