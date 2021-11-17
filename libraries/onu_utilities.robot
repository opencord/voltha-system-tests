# Copyright 2020 - present Open Networking Foundation
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
Documentation     Library for various openonu-go-adpter utilities
Library           grpc_robot.VolthaTools     WITH NAME    volthatools


*** Keywords ***
Calculate Timeout
    [Documentation]    Calculates the timeout regarding num-onus in case of more than 4 onus
    [Arguments]    ${basetimeout}=60s
    ${new_timeout}    Fetch From Left    ${basetimeout}    s
    ${new_timeout}=    evaluate    ${new_timeout}+((${num_all_onus}-4)*10)
    ${new_timeout}=    Set Variable If    (not ${debugmode}) and (${new_timeout}>300)
    ...    300   ${new_timeout}
    ${new_timeout}=    Catenate    SEPARATOR=    ${new_timeout}    s
    [Return]    ${new_timeout}

Get Logical Id of OLT
    [Documentation]    Fills the logical id of OLT(s) if missing
    FOR    ${I}    IN RANGE    0    ${num_olts}
        # exit loop if logical id already known
        Exit For Loop IF    "${olt_ids}[${I}][logical_id]" != "${EMPTY}"
        #read current device values
        ${olt}=    Get From List    ${olt_ids}    ${I}
        ${olt_serial_number}=     Get From Dictionary    ${olt}    sn
        # read logical id and store it
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        Set To Dictionary    ${olt}    logical_id    ${logical_id}
        Set List Value    ${olt_ids}    ${I}    ${olt}
    END
    Set Global Variable    ${olt_ids}

Power On ONU Device
    [Documentation]    This keyword turns on the power for all onus.
    [Arguments]    ${namespace}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${namespace}    release     ${bbsim}
        Power On ONU Device per OLT    ${namespace}   ${olt_serial_number}    ${bbsim_pod}
    END

Power On ONU Device per OLT
    [Documentation]    This keyword turns on the power for all onus.
    [Arguments]    ${namespace}    ${olt_serial_number}    ${bbsim_pod}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        Power On ONU    ${namespace}    ${bbsim_pod}    ${src['onu']}
    END

Power Off ONU Device
    [Documentation]    This keyword turns off the power for all onus per olt.
    [Arguments]    ${namespace}
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${namespace}    release     ${bbsim}
        Power Off ONU Device per OLT    ${namespace}   ${olt_serial_number}    ${bbsim_pod}
    END

Power Off ONU Device per OLT
    [Documentation]    This keyword turns off the power for all onus per olt.
    [Arguments]    ${namespace}    ${olt_serial_number}    ${bbsim_pod}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        Power Off ONU    ${namespace}    ${bbsim_pod}    ${src['onu']}
    END

Current State Test
    [Documentation]    This keyword checks the passed state of the given onu.
    [Arguments]    ${state}    ${onu}    ${reqadminstate}=${EMPTY}    ${reqoperstatus}=${EMPTY}
    ...    ${reqconnectstatus}=${EMPTY}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=    Map State    ${state}
    ${admin_state}=       Set Variable If    '${reqadminstate}'!='${EMPTY}'       ${reqadminstate}       ${admin_state}
    ${oper_status}=       Set Variable If    '${reqoperstatus}'!='${EMPTY}'       ${reqoperstatus}       ${oper_status}
    ${connect_status}=    Set Variable If    '${reqconnectstatus}'!='${EMPTY}'    ${reqconnectstatus}
    ...    ${connect_status}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${onu}    onu=True    onu_reason=${onu_state}

Current State Test All Onus
    [Documentation]    This keyword checks the passed state of all onus.
    ...                Hint: ${timeStart} will be not evaluated here!
    [Arguments]    ${state}    ${reqadminstate}=${EMPTY}    ${reqoperstatus}=${EMPTY}    ${reqconnectstatus}=${EMPTY}
    ...    ${alternativeonustate}=${EMPTY}    ${timeout}=${timeout}
    ${timeStart}=    Get Current Date
    ${list_onus}    Create List
    Build ONU SN List    ${list_onus}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=    Map State    ${state}
    ${admin_state}=       Set Variable If    '${reqadminstate}'!='${EMPTY}'       ${reqadminstate}       ${admin_state}
    ${oper_status}=       Set Variable If    '${reqoperstatus}'!='${EMPTY}'       ${reqoperstatus}       ${oper_status}
    ${connect_status}=    Set Variable If    '${reqconnectstatus}'!='${EMPTY}'    ${reqconnectstatus}
    ...    ${connect_status}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration
    ...    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${onu_state}    ${list_onus}    ${timeStart}    alternate_reason=${alternativeonustate}
    # teardown is used as 'return' for result of Validate ONU Devices With Duration (used for ONUNegativeStateTests)
    [Teardown]    Run Keyword If    "${KEYWORD STATUS}"=="FAIL"    Set Suite Variable    ${StateTestAllONUs}    False

Reconcile Onu Adapter
    [Documentation]     Restarts the openonu adapter and waits for reconciling is finished and expected oper-state is reached
    [Arguments]     ${namespace}    ${usekill2restart}    ${oper_status}    ${olt_to_be_deleted_sn}=${EMPTY}
    # get time of restart of openonu adapter
    ${restart_ts}=    Get Current Date
    # restart OpenONU adapter
    Run Keyword If    ${usekill2restart}    Kill And Check Onu Adaptor    ${namespace}
    ...    ELSE    Restart And Check Onu Adaptor    ${namespace}
    #check ready timestamp of openonu adapter, should be younger than restart timestamp
    ${openonu_ready_ts}=    Get Pod Ready Timestamp by Label    ${namespace}    app    adapter-open-onu
    ${restart_duration}=    Subtract Date From Date    ${openonu_ready_ts}    ${restart_ts}
    Should Be True     ${restart_duration}>0
    # delete the olt passed, if available (special feature)
    ${olt_to_be_deleted_device_id}=    Run Keyword IF  "${olt_to_be_deleted_sn}"!="${EMPTY}"
    ...    Get OLTDeviceID From OLT List    ${olt_to_be_deleted_sn}
    Run Keyword IF  "${olt_to_be_deleted_sn}"!="${EMPTY}"    Delete Device    ${olt_to_be_deleted_device_id}
    # wait for the reconcile to complete
    # - we check that communication to openonu-adapter is established again
    # - we check that all ONUs leave reconcile state by validate a simple voltctl request will not responds with error
    Wait Until Keyword Succeeds    ${timeout}    1s    Validate Last ONU Communication
    Wait Until Keyword Succeeds    ${timeout}    1s    Validate All Onus Accessible    ${olt_to_be_deleted_sn}
    # - then we wait that all ONU move to the next state, except ONU belonging to deleted OLT (special feature)
    ${list_onus}    Create List
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        Continue For Loop If    "${olt_to_be_deleted_sn}"=="${olt_serial_number}"
        Build ONU SN List    ${list_onus}
    END
    Run Keyword And Ignore Error    Wait Until Keyword Succeeds    ${timeout}
    ...     1s  Check all ONU OperStatus     ${list_onus}  ${oper_status}

Validate All Onus Accessible
    [Documentation]    This keyword checks all onus accessible (again) with help of a simple voltctl request.
    ...                As long we've got an rc!=0 keyword will fail -> onu is not accessible.
    ...                As get request Onu image list is used, any other get command could be used for this check.
    ...                Will not check ONUs of passed deleted OLT (special feature)
    [Arguments]     ${deleted_olt}=${EMPTY}
    ${onu_list}    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${olt_serial_number}=    Set Variable    ${src['olt']}
        Continue For Loop If    "${deleted_olt}"=="${olt_serial_number}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_id}=    Get Index From List    ${onu_list}   ${onu_device_id}
        Continue For Loop If    -1 != ${onu_id}
        Append To List    ${onu_list}    ${onu_device_id}
        ${rc}    ${output}=    Get Onu Image List    ${onu_device_id}
        Should Be True    ${rc}==0    Onu ${src['onu']} (${onu_device_id}) still not accessible.
    END

Log Ports
    [Documentation]    This keyword logs all port data available in ONOS of first port per ONU
    [Arguments]    ${onlyenabled}=False
    ${cmd}    Set Variable If    ${onlyenabled}    ports -e    ports
    ${onu_ports}=    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}   ${cmd}
    ${lines} =     Get Lines Matching Regexp    ${onu_ports}    .*portName=BBSM[0-9]{8}-1
    Log    ${lines}

Kill Adaptor
    [Documentation]    This keyword kills the passed adaptor.
    [Arguments]    ${namespace}    ${name}
    ${cmd}    Catenate
    ...    kubectl exec -it -n voltha $(kubectl get pods -n ${namespace} | grep ${name} | awk 'NR==1{print $1}')
    ...     -- /bin/sh -c "kill 1"
    ${rc}    ${output}=    Run and Return Rc and Output    ${cmd}
    Log    ${output}

Kill And Check Onu Adaptor
    [Documentation]    This keyword kills ONU Adaptor and waits for it to come up again
    ...    Following steps will be executed:
    ...    - kill openonu adaptor
    ...    - check openonu adaptor is ready again
    [Arguments]    ${namespace}
    ${list_openonu_apps}   Create List    adapter-open-onu
    ${adaptorname}=    Set Variable    open-onu
    Kill Adaptor    ${namespace}    ${adaptorname}
    Sleep    5s
    Wait For Pods Ready    ${namespace}    ${list_openonu_apps}

Restart And Check Onu Adaptor
    [Documentation]    This keyword restarts ONU Adaptor and waits for it to come up again
    ...    Following steps will be executed:
    ...    - restart openonu adaptor
    ...    - check openonu adaptor is ready again
    [Arguments]    ${namespace}
    ${list_openonu_apps}   Create List    adapter-open-onu
    ${openonu_label_key}    Set Variable   app
    ${openonu_label_value}    Set Variable   adapter-open-onu
    Restart Pod By Label    ${namespace}    ${openonu_label_key}    ${openonu_label_value}
    Sleep    5s
    Wait For Pods Ready    ${namespace}    ${list_openonu_apps}

Disable Onu Device
    [Documentation]    This keyword disables all onus.
    ${onu_list}    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_id}=    Get Index From List    ${onu_list}   ${onu_device_id}
        Continue For Loop If    -1 != ${onu_id}
        Append To List    ${onu_list}    ${onu_device_id}
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    20s    2s    Test Devices Disabled in VOLTHA    Id=${onu_device_id}
    END

Enable Onu Device
    [Documentation]    This keyword enables all onus.
    ${onu_list}    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_id}=    Get Index From List    ${onu_list}   ${onu_device_id}
        Continue For Loop If    -1 != ${onu_id}
        Append To List    ${onu_list}    ${onu_device_id}
        Enable Device    ${onu_device_id}
    END

Verify MIB Template Data Available
    [Documentation]    This keyword verifies MIB Template Data stored in etcd
    [Arguments]    ${namespace}=default
    ${podname}=      Set Variable    etcd
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Should Not Be Empty    ${result}    No MIB Template Data stored in etcd!

Delete MIB Template Data
    [Documentation]    This keyword deletes MIB Template Data stored in etcd
    [Arguments]    ${namespace}=default
    ${podname}=    Set Variable    etcd
    ${commanddel}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commanddel}
    Sleep    3s
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Should Be Empty    ${result}    Could not delete MIB Template Data stored in etcd!

Set Tech Profile
    [Documentation]    This keyword sets the passed TechProfile for the test
    [Arguments]    ${TechProfile}    ${namespace}=default
    Log To Console    \nTechProfile:${TechProfile}
    ${podname}=    Set Variable    etcd
    ${label}=    Set Variable    app.kubernetes.io/name=${podname}
    ${src}=    Set Variable    ${data_dir}/TechProfile-${TechProfile}.json
    ${dest}=    Set Variable    /tmp/flexpod.json
    ${command}    Catenate
    ...    /bin/sh -c 'cat    ${dest} | ETCDCTL_API=3 etcdctl put service/voltha/technology_profiles/XGS-PON/64'
    Copy File To Pod    ${namespace}    ${label}    ${src}    ${dest}
    Exec Pod In Kube    ${namespace}    ${podname}    ${command}
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Should Not Be Empty    ${result}    No Tech Profile stored in etcd!

Remove Tech Profile
    [Documentation]    This keyword removes TechProfile
    [Arguments]    ${namespace}=default
    Log To Console    \nTechProfile:${TechProfile}
    ${podname}=    Set Variable    etcd
    ${command}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod In Kube    ${namespace}    ${podname}    ${command}
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}

Do Onu Subscriber Add Per OLT
    [Documentation]    Add Subscriber per OLT
    [Arguments]    ${of_id}    ${olt_serial_number}    ${print2console}=False
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${print2console}    Log    \r\n[${I}] volt-add-subscriber-access ${of_id} ${onu_port}.
        ...   console=yes
    END

Do Onu Flow Check Per OLT
    [Documentation]    Checks all ONU flows show up in ONOS and Voltha
    [Arguments]    ${of_id}    ${nni_port}    ${olt_serial_number}    ${print2console}=False
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
        ${logoutput}    Catenate    \r\n[${I}] Verify Subscriber Access Flows Added For
        ...    ONU ${of_id}    ${onu_port}    ${src['c_tag']}    ${src['s_tag']}.
        Run Keyword If    ${print2console}    Log    ${logoutput}    console=yes
    END

Do Onu Subscriber Remove Per OLT
    [Documentation]    Removes per OLT subscribers in ONOS and Voltha
    [Arguments]    ${of_id}    ${olt_serial_number}    ${print2console}=False
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-remove-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${print2console}    Log    \r\n[${I}] volt-remove-subscriber-access ${of_id} ${onu_port}.
        ...    console=yes
    END

Validate Resource Instances Used Gem Ports
    [Documentation]    This keyword validates resource instances data stored in etcd.
    ...                It checks checks the number of gemport-ids which has matched with used Tech Profile
    [Arguments]    ${nbofgemports}    ${namespace}=default    ${defaultkvstoreprefix}=voltha_voltha
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${etcddata}=    Get ONU Go Adapter ETCD Data    namespace=${namespace}    defaultkvstoreprefix=${kvstoreprefix}
    #prepare result for json convert
    ${result}=    Prepare ONU Go Adapter ETCD Data For Json    ${etcddata}
    ${jsondata}=    To Json    ${result}
    ${length}=    Get Length    ${jsondata}
    log    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        # TODO: The TP ID is hardcoded to 64 below. It is fine when testing single-tcont workflow.
        # When testing multi-tcont this may need some adjustment.
        Exit For Loop If    not ('uni_config' in $value)
        ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]['PersTpPathMap']}    64
        ${resourcedata}=    Get Resource Instances ETCD Data    ${tp_path}    namespace=${namespace}
        ...    defaultkvstoreprefix=${kvstoreprefix}
        log    ${resourcedata}
        ${decoderesult}=    volthatools.Tech Profile Decode Resource Instance    ${resourcedata}    return_default=true
        log    ${decoderesult}
        ${gemportids}=    Get From Dictionary    ${decoderesult}    gemport_ids
        ${length}=    Get Length    ${gemportids}
        Should Be Equal As Integers    ${nbofgemports}    ${length}
        ...    msg=Number of gem ports (${length}) does not match with techprofile ${techprofile}/${nbofgemports}
    END

Get Resource Instances ETCD Data
    [Documentation]    This keyword delivers Resource Instances Data stored in etcd
    [Arguments]    ${tppath}    ${namespace}=default    ${defaultkvstoreprefix}=voltha_voltha
    ${podname}=    Set Variable    etcd
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/resource_instances/${tppath}
    ...    --print-value-only --hex'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    log    ${result}
    [Return]    ${result}


Validate Onu Data In Etcd
    [Documentation]    This keyword validates openonu-go-adapter Data stored in etcd.
    ...                It checks unique of  serial_number and combination of pon, onu and uni in tp_path.
    ...                Furthermore it evaluates the values of onu_id and uni_id with values read from tp_path.
    ...                Number of etcd entries has to match with the passed number.
    [Arguments]    ${namespace}=default    ${nbofetcddata}=${num_all_onus}    ${defaultkvstoreprefix}=voltha_voltha
    ...            ${without_prefix}=True    ${without_pm_data}=True
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${etcddata}=    Get ONU Go Adapter ETCD Data    ${namespace}    ${kvstoreprefix}    ${without_prefix}    ${without_pm_data}
    #prepare result for json convert
    ${result}=    Prepare ONU Go Adapter ETCD Data For Json    ${etcddata}
    ${jsondata}=    To Json    ${result}
    ${length}=    Get Length    ${jsondata}
    log    ${jsondata}
    Run Keyword And Continue On Failure    Should Be Equal As Integers    ${length}    ${nbofetcddata}
    ...    msg=Number etcd data (${length}) does not match required (${nbofetcddata})!
    ${oltpononuuniidlist}=    Create List
    ${serialnumberlist}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        # TODO: The TP ID is hardcoded to 64 below. It is fine when testing single-tcont workflow.
        # When testing multi-tcont this may need some adjustment.
        Exit For Loop If    not ('uni_config' in $value)
        ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]['PersTpPathMap']}    64
        ${oltpononuuniid}=    Read Pon Onu Uni String    ${tp_path}
        ${list_id}=    Get Index From List    ${oltpononuuniidlist}   ${oltpononuuniid}
        Should Be Equal As Integers    ${list_id}    -1
        ...    msg=Combination of Pon, Onu and Uni (${oltpononuuniid}) exist multiple in etcd data!
        Append To List    ${oltpononuuniidlist}    ${oltpononuuniid}
        Validate Onu Id    ${value}
        Validate Uni Id    ${value}
        ${serial_number}=    Get From Dictionary    ${value}    serial_number
        ${list_id}=    Get Index From List    ${serialnumberlist}   ${serial_number}
        Should Be Equal As Integers    ${list_id}    -1
        ...    msg=Serial number (${serial_number}) exists multiple in etcd data!
        Append To List    ${serialnumberlist}    ${serial_number}
    END

Validate Onu Data In Etcd Removed
    [Documentation]    This keyword validates openonu-go-adapter Data stored in etcd are removed.
    ...                In case of a device is passed, only this will be checked.
    [Arguments]    ${namespace}=default    ${device_id}=${EMPTY}    ${defaultkvstoreprefix}=voltha_voltha
    ...            ${without_pm_data}=True
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${etcddata}=    Get ONU Go Adapter ETCD Data    ${namespace}    ${kvstoreprefix}    False    ${without_pm_data}
    ...             ${device_id}    True
    Log    ${etcddata}
    Should Be Empty    ${etcddata}    Stale Openonu Data in Etcd (KV store) ${device_id}

Validate Vlan Rules In Etcd
    [Documentation]    This keyword validates Vlan rules of openonu-go-adapter Data stored in etcd.
    ...                It checks the given number of cookie_slice, match_vid (=4096) and set_vid.
    ...                Furthermore it returns a list of all set_vid.
    ...                In case of a passed dictionary containing set_vids these will be checked for to
    ...                current set-vid depending on setvidequal (True=equal, False=not equal).
    [Arguments]    ${namespace}=default    ${nbofcookieslice}=1    ${reqmatchvid}=4096    ${prevvlanrules}=${NONE}
    ...    ${setvidequal}=False    ${defaultkvstoreprefix}=voltha_voltha    ${without_prefix}=True    ${without_pm_data}=True
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${etcddata}=    Get ONU Go Adapter ETCD Data    ${namespace}    ${kvstoreprefix}    ${without_prefix}    ${without_pm_data}
    #prepare result for json convert
    ${result}=    Prepare ONU Go Adapter ETCD Data For Json    ${etcddata}
    ${jsondata}=    To Json    ${result}
    ${length}=    Get Length    ${jsondata}
    log    ${jsondata}
    ${vlan_rules}=    Create Dictionary
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        # TODO: The TP ID is hardcoded to 64 below. It is fine when testing single-tcont workflow.
        # When testing multi-tcont this may need some adjustment.
        ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]['PersTpPathMap']}    64
        ${oltpononuuniid}=    Read Pon Onu Uni String    ${tp_path}
        ${cookieslice}=    Get From Dictionary    ${value['uni_config'][0]['flow_params'][0]}    cookie_slice
        #@{cookieslicelist}=    Split String    ${cookieslice}    ,
        ${foundcookieslices}=    Get Length    ${cookieslice}
        Should Be Equal As Integers    ${foundcookieslices}    ${nbofcookieslice}
        ${matchvid}=    Get From Dictionary    ${value['uni_config'][0]['flow_params'][0]['vlan_rule_params']}
        ...    match_vid
        Should Be Equal As Integers    ${matchvid}    ${reqmatchvid}
        ${setvid}=    Get From Dictionary    ${value['uni_config'][0]['flow_params'][0]['vlan_rule_params']}
        ...    set_vid
        ${evalresult}=    Evaluate    2 <= ${setvid} <= 4095
        Should Be True    ${evalresult}    msg=set_vid out of range (${setvid})!
        Set To Dictionary    ${vlan_rules}    ${oltpononuuniid}    ${setvid}
        ${oldsetvidvalid}     Set Variable If    ${prevvlanrules} is ${NONE}    False    True
        ${prevsetvid}=    Set Variable If    ${oldsetvidvalid}    ${prevvlanrules['${oltpononuuniid}']}
        Run Keyword If    ${oldsetvidvalid} and ${setvidequal}
        ...               Should Be Equal As Integers    ${prevsetvid}    ${setvid}
        ...    ELSE IF    ${oldsetvidvalid} and not ${setvidequal}
        ...               Should Not Be Equal As Integers    ${prevsetvid}    ${setvid}
    END
    log Many    ${vlan_rules}
    [Return]    ${vlan_rules}

Get ONU Go Adapter ETCD Data
    [Documentation]    This keyword delivers openonu-go-adapter Data stored in etcd
    [Arguments]    ${namespace}=default    ${defaultkvstoreprefix}=voltha_voltha    ${without_prefix}=True
    ...    ${without_pm_data}=True    ${device_id}=${Empty}    ${keys_only}=False
    ${podname}=    Set Variable    etcd
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/openonu'
    ${commandget}=    Run Keyword If    ${keys_only}     Catenate    ${commandget}     --keys-only
    ...    ELSE    Set Variable    ${commandget}
    ${commandget}=    Run Keyword If    ${without_prefix}     Catenate    ${commandget}
    ...    | grep -v service/${kvstoreprefix}/openonu
    ...    ELSE    Set Variable    ${commandget}
    ${commandget}=    Run Keyword If    ${without_pm_data}    Catenate    ${commandget}    | grep -v instances_active
    ...    ELSE    Set Variable    ${commandget}
    ${commandget}=    Run Keyword If    "${device_id}"!="${Empty}"    Catenate    ${commandget}    | grep ${device_id}
    ...    ELSE    Set Variable    ${commandget}
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    log    ${result}
    [Return]    ${result}

Prepare ONU Go Adapter ETCD Data For Json
    [Documentation]    This keyword prepares openonu-go-adapter Data stored in etcd for converting
    ...                to json
    [Arguments]    ${etcddata}
    #prepare result for json convert
    ${prepresult}=    Replace String    ${etcddata}   \n    ,
    ${prepresult}=    Strip String    ${prepresult}    mode=right    characters=,
    ${prepresult}=    Set Variable    [${prepresult}]
    log    ${prepresult}
    [Return]    ${prepresult}

Read Pon Onu Uni String
    [Documentation]    This keyword builds a four digit string using Olt, Pon, Onu and Uni value of given tp-path taken
    ...                taken from etcd data of onu go adapter
    [Arguments]    ${tp_path}
    ${tppathlines}=   Replace String    ${tp_path}    /    \n
    ${olt}=    Get Value Of Tp Path Element    ${tppathlines}    olt
    ${pon}=    Get Value Of Tp Path Element    ${tppathlines}    pon
    ${onu}=    Get Value Of Tp Path Element    ${tppathlines}    onu
    ${uni}=    Get Value Of Tp Path Element    ${tppathlines}    uni
    ${valuesid}=    Set Variable   ${olt}/${pon}/${onu}/${uni}
    log    ${valuesid}
    [Return]    ${valuesid}

Get Value Of Tp Path Element
    [Documentation]    This keyword delivers numeric value of given tp path element.
    [Arguments]    ${tp_path_lines}    ${element}
    ${value}=    Get Lines Containing String    ${tp_path_lines}    ${element}-\{
    ${value}=    Remove String    ${value}    ${element}-\{
    ${value}=    Remove String    ${value}    \}
    log    ${value}
    [Return]    ${value}

Validate Onu Id
    [Documentation]    This keyword validates ONU Id of passed etcd data.
    [Arguments]    ${value}
    # TODO: The TP ID is hardcoded to 64 below. It is fine when testing single-tcont workflow.
    # When testing multi-tcont this may need some adjustment.
    ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]['PersTpPathMap']}    64
    ${tppathlines}=   Replace String    ${tp_path}    /    \n
    ${onu}=    Get Value Of Tp Path Element    ${tppathlines}    onu
    ${onu_id}=    Get From Dictionary    ${value}    onu_id
    Should Be Equal As Integers    ${onu}    ${onu_id}
    ...    msg=Onu-Id (${onu_id}) does not match onu (${onu}) from tp_path in etcd data!
    Should Be True    ${onu_id}>=1

Validate Uni Id
    [Documentation]    This keyword validates UNI Id of passed etcd data.
    [Arguments]    ${value}
    # TODO: The TP ID is hardcoded to 64 below. It is fine when testing single-tcont workflow.
    # When testing multi-tcont this may need some adjustment.
    ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]['PersTpPathMap']}    64
    ${tppathlines}=   Replace String    ${tp_path}    /    \n
    ${uni}=    Get Value Of Tp Path Element    ${tppathlines}    uni
    ${uni_id}=    Get From Dictionary    ${value['uni_config'][0]}    uni_id
    Should Be Equal As Integers    ${uni}    ${uni_id}
    ...    msg=Uni-Id (${uni_id}) does not match onu (${uni}) from tp_path in etcd data!

Delete ONU Go Adapter ETCD Data
    [Documentation]    This keyword deletes openonu-go-adapter Data stored in etcd
    [Arguments]    ${namespace}=default    ${defaultkvstoreprefix}=voltha_voltha    ${validate}=False
    ${podname}=    Set Variable    etcd
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/${kvstoreprefix}/openonu'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    log    ${result}
    Run Keyword If    ${validate}    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Onu Data In Etcd    namespace=${namespace}    nbofetcddata=0    without_pm_data=False
    [Return]    ${result}

Wait for Ports in ONOS for all OLTs
    [Documentation]    Waits untill a certain number of ports are enabled in all OLTs
    [Arguments]    ${host}    ${port}    ${count}    ${filter}    ${max_wait_time}=10m   ${determine_number}=False
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${count2check}=    Set Variable If    ${count}==${num_all_onus}    ${onu_count}    ${count}
        # if flag determine_number is set to True, always determine the number of real ONUs (overwrite previous value)
        ${count2check}=    Run Keyword If    ${determine_number}    Determine Number Of ONU    ${olt_serial_number}
        ...                ELSE              Set Variable    ${count2check}
        Wait for Ports in ONOS    ${host}    ${port}    ${count2check}    ${of_id}    BBSM    ${max_wait_time}
    END

Wait for all ONU Ports in ONOS Disabled
    [Documentation]    Waits untill a all ONU ports are disabled in all ONOS
    [Arguments]    ${host}    ${port}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${src['olt']}
       ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Assert ONU Port Is Disabled    ${host}    ${port}    ${of_id}
        ...    ${onu_port}
    END

Map State
    [Documentation]    This keyword converts the passed numeric value or name of a onu state to its state values.
    [Arguments]    ${state}
    # create state lists with corresponding return values
    #                             ADMIN-STATE OPER-STATUS   CONNECT-STATUS ONU-STATE (number/name)
    ${state1}     Create List      ENABLED     ACTIVATING    REACHABLE       1    activating-onu
    ${state2}     Create List      ENABLED     ACTIVATING    REACHABLE       2    starting-openomci
    ${state3}     Create List      ENABLED     ACTIVATING    REACHABLE       3    discovery-mibsync-complete
    ${state4}     Create List      ENABLED     ACTIVE        REACHABLE       4    initial-mib-downloaded
    ${state5}     Create List      ENABLED     ACTIVE        REACHABLE       5    tech-profile-config-download-success
    ${state6}     Create List      ENABLED     ACTIVE        REACHABLE       6    omci-flows-pushed
    ${state7}     Create List      DISABLED    UNKNOWN       REACHABLE       7    omci-admin-lock
    ${state8}     Create List      ENABLED     ACTIVE        REACHABLE       8    onu-reenabled
    ${state9}     Create List      ENABLED     DISCOVERED    UNREACHABLE     9    stopping-openomci
    ${state10}    Create List      ENABLED     DISCOVERED    REACHABLE      10    rebooting
    ${state11}    Create List      ENABLED     DISCOVERED    REACHABLE      11    omci-flows-deleted
    ${state12}    Create List      DISABLED    UNKNOWN       REACHABLE      12    tech-profile-config-delete-success
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=    Set Variable If
    ...    '${state}'=='1' or '${state}'=='activating-onu'                          ${state1}
    ...    '${state}'=='2' or '${state}'=='starting-openomci'                       ${state2}
    ...    '${state}'=='3' or '${state}'=='discovery-mibsync-complete'              ${state3}
    ...    '${state}'=='4' or '${state}'=='initial-mib-downloaded'                  ${state4}
    ...    '${state}'=='5' or '${state}'=='tech-profile-config-download-success'    ${state5}
    ...    '${state}'=='6' or '${state}'=='omci-flows-pushed'                       ${state6}
    ...    '${state}'=='7' or '${state}'=='omci-admin-lock'                         ${state7}
    ...    '${state}'=='8' or '${state}'=='onu-reenabled'                           ${state8}
    ...    '${state}'=='9' or '${state}'=='stopping-openomci'                       ${state9}
    ...    '${state}'=='10' or '${state}'=='rebooting'                              ${state10}
    ...    '${state}'=='11' or '${state}'=='omci-flows-deleted'                     ${state11}
    ...    '${state}'=='12' or '${state}'=='tech-profile-config-delete-success'     ${state12}
    [Return]    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}
