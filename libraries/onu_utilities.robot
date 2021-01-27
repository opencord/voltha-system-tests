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

*** Variables ***
${defaultstackname}    voltha_voltha

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

Power On ONU Device
    [Documentation]    This keyword turns on the power for all onus.
    [Arguments]    ${namespace}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${result}=    Exec Pod In Kube    ${namespace}    bbsim    bbsimctl onu poweron ${src['onu']}
        Should Contain    ${result}    successfully    msg=Can not poweron ${src['onu']}    values=False
    END

Power Off ONU Device
    [Documentation]    This keyword turns off the power for all onus.
    [Arguments]    ${namespace}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${result}=    Exec Pod In Kube    ${namespace}    bbsim    bbsimctl onu shutdown ${src['onu']}
        Should Contain    ${result}    successfully    msg=Can not shutdown ${src['onu']}    values=False
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
    ...    ${alternativeonustate}=${EMPTY}
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

Log Ports
    [Documentation]    This keyword logs all port data available in ONOS of first port per ONU
    [Arguments]    ${onlyenabled}=False
    ${cmd}    Set Variable If    ${onlyenabled}    ports -e    ports
    ${onu_ports}=    Execute ONOS CLI Command on open connection    ${onos_ssh_connection}   ${cmd}
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
    ${adaptorname}=    Set Variable    open-onu
    Restart Pod    ${namespace}    ${adaptorname}
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
    ${namespace}=    Set Variable    default
    ${podname}=      Set Variable    etcd
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Should Not Be Empty    ${result}    No MIB Template Data stored in etcd!

Delete MIB Template Data
    [Documentation]    This keyword deletes MIB Template Data stored in etcd
    ${namespace}=    Set Variable    default
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
    [Arguments]    ${TechProfile}
    Log To Console    \nTechProfile:${TechProfile}
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${src}=    Set Variable    ${data_dir}/TechProfile-${TechProfile}.json
    ${dest}=    Set Variable    /tmp/flexpod.json
    ${command}    Catenate
    ...    /bin/sh -c 'cat    ${dest} | ETCDCTL_API=3 etcdctl put service/voltha/technology_profiles/XGS-PON/64'
    Copy File To Pod    ${namespace}    ${podname}    ${src}    ${dest}
    Exec Pod In Kube    ${namespace}    ${podname}    ${command}
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}

Remove Tech Profile
    [Documentation]    This keyword removes TechProfile
    Log To Console    \nTechProfile:${TechProfile}
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${command}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod In Kube    ${namespace}    ${podname}    ${command}
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}

Validate Onu Data In Etcd
    [Documentation]    This keyword validates openonu-go-adapter Data stored in etcd.
    ...                It checks unique of  serial_number and combination of pon, onu and uni in tp_path.
    ...                Furthermore it evaluates the values of onu_id and uni_id with values read from tp_path.
    ...                Number of etcd entries has to match with the passed number.
    [Arguments]    ${nbofetcddata}=${num_all_onus}
    ${stackname}=    Get Stack Name
    ${etcddata}=    Get ONU Go Adapter ETCD Data
    ${etcddata}=    Remove Lines Containing String    ${etcddata}    service/${stackname}/openonu    \n
    #prepare result for json convert
    ${result}=    Prepare ONU Go Adapter ETCD Data For Json    ${etcddata}
    ${jsondata}=    To Json    ${result}
    ${length}=    Get Length    ${jsondata}
    log    ${jsondata}
    Run Keyword And Continue On Failure    Should Be Equal As Integers    ${length}    ${nbofetcddata}
    ...    msg=Number etcd data (${length}) does not match required (${nbofetcddata})!
    ${pononuuniidlist}=    Create List
    ${serialnumberlist}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        # TODO: The TP ID is hardcoded to 64 below. It is fine when testing single-tcont workflow.
        # When testing multi-tcont this may need some adjustment.
        ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]['PersTpPathMap']}    64
        ${pononuuniid}=    Read Pon Onu Uni String    ${tp_path}
        ${list_id}=    Get Index From List    ${pononuuniidlist}   ${pononuuniid}
        Should Be Equal As Integers    ${list_id}    -1
        ...    msg=Combination of Pon, Onu and Uni (${pononuuniid}) exist multiple in etcd data!
        Append To List    ${pononuuniidlist}    ${pononuuniid}
        Validate Onu Id    ${value}
        Validate Uni Id    ${value}
        ${serial_number}=    Get From Dictionary    ${value}    serial_number
        ${list_id}=    Get Index From List    ${serialnumberlist}   ${serial_number}
        Should Be Equal As Integers    ${list_id}    -1
        ...    msg=Serial number (${serial_number}) exists multiple in etcd data!
        Append To List    ${serialnumberlist}    ${serial_number}
    END

Validate Vlan Rules In Etcd
    [Documentation]    This keyword validates Vlan rules of openonu-go-adapter Data stored in etcd.
    ...                It checks the given number of cookie_slice, match_vid (=4096) and set_vid.
    ...                Furthermore it returns a list of all set_vid.
    ...                In case of a passed dictionary containing set_vids these will be checked for to
    ...                current set-vid depending on setvidequal (True=equal, False=not equal).
    [Arguments]    ${nbofcookieslice}=1    ${reqmatchvid}=4096    ${prevvlanrules}=${NONE}    ${setvidequal}=False
    ${stackname}=    Get Stack Name
    ${etcddata}=    Get ONU Go Adapter ETCD Data
    ${etcddata}=    Remove Lines Containing String    ${etcddata}    service/${stackname}/openonu    \n
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
        ${pononuuniid}=    Read Pon Onu Uni String    ${tp_path}
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
        Set To Dictionary    ${vlan_rules}    ${pononuuniid}    ${setvid}
        ${oldsetvidvalid}     Set Variable If    ${prevvlanrules} is ${NONE}    False    True
        ${prevsetvid}=    Set Variable If    ${oldsetvidvalid}    ${prevvlanrules['${pononuuniid}']}
        Run Keyword If    ${oldsetvidvalid} and ${setvidequal}
        ...               Should Be Equal As Integers    ${prevsetvid}    ${setvid}
        ...    ELSE IF    ${oldsetvidvalid} and not ${setvidequal}
        ...               Should Not Be Equal As Integers    ${prevsetvid}    ${setvid}
    END
    log Many    ${vlan_rules}
    [Return]    ${vlan_rules}

Get ONU Go Adapter ETCD Data
    [Documentation]    This keyword delivers openonu-go-adapter Data stored in etcd
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${stackname}=    Get Stack Name
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix --prefix service/${stackname}/openonu'
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

Remove Lines Containing String
    [Documentation]    This keyword deletes all lines from given string containing passed remove string
    [Arguments]    ${string}    ${toremove}    ${appendtoremoveline}
    ${lines}=    Get Lines Containing String    ${string}    ${toremove}
    ${length}=    Get Line Count    ${lines}
    ${firstline}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${String2remove}    Get Line    ${lines}    ${INDEX}
        ${String2remove}    Set Variable    ${String2remove}${appendtoremoveline}
        ${string}=    Remove String    ${string}    ${String2remove}
    END
    log    ${string}
    [Return]    ${string}

Read Pon Onu Uni String
    [Documentation]    This keyword builds a thre digit string using Pon, Onu and Uni value of given tp-path taken
    ...                taken from etcd data of onu go adapter
    [Arguments]    ${tp_path}
    ${tppathlines}=   Replace String    ${tp_path}    /    \n
    ${pon}=    Get Value Of Tp Path Element    ${tppathlines}    pon
    ${onu}=    Get Value Of Tp Path Element    ${tppathlines}    onu
    ${uni}=    Get Value Of Tp Path Element    ${tppathlines}    uni
    ${valuesid}=    Set Variable   ${pon}/${onu}/${uni}
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

Get Stack Name
    [Documentation]    This keyword delivers the stack name read from environment variable NAME if present.
    ${env_name}=    Get Environment Variable    NAME    default=${defaultstackname}
    # while Get Environment Variable does not work correctly, a manual correction follows
    ${env_name}=    Set Variable If    "${env_name}"=="${EMPTY}"    ${defaultstackname}    ${env_name}
    [Return]    ${env_name}

Wait for Ports in ONOS for all OLTs
    [Documentation]    Waits untill a certain number of ports are enabled in all OLTs
    [Arguments]    ${onos_ssh_connection}    ${count}    ${filter}    ${max_wait_time}=10m
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        Wait for Ports in ONOS    ${onos_ssh_connection}    ${count}    ${of_id}    BBSM    ${max_wait_time}
    END

Wait for all ONU Ports in ONOS Disabled
    [Documentation]    Waits untill a all ONU ports are disabled in all ONOS
    [Arguments]    ${onos_ssh_connection}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${src['olt']}
       ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Assert ONU Port Is Disabled    ${onos_ssh_connection}    ${of_id}
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