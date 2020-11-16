# Copyright 2020-present Open Networking Foundation
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
Documentation     Library for various openonu-go-adpter utilities

*** Keywords ***
Do Power On ONU Device
    [Documentation]    This keyword power on all onus.
    ${namespace}=    Set Variable    voltha
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${result}=    Exec Pod    ${namespace}    bbsim    bbsimctl onu poweron ${src['onu']}
        Should Contain    ${result}    successfully    msg=Can not poweron ${src['onu']}    values=False
    END

Do Current State Test
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

Do Current State Test All Onus
    [Documentation]    This keyword checks the passed state of all onus.
    ...                Hint: ${timeStart} will be not evaluated here!
    [Arguments]    ${state}    ${reqadminstate}=${EMPTY}    ${reqoperstatus}=${EMPTY}    ${reqconnectstatus}=${EMPTY}
    ...    ${alternativeonustate}=${EMPTY}
    ${list_onus}    Create List
    Build ONU SN List    ${list_onus}    ${olt_serial_number}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=    Map State    ${state}
    ${admin_state}=       Set Variable If    '${reqadminstate}'!='${EMPTY}'       ${reqadminstate}       ${admin_state}
    ${oper_status}=       Set Variable If    '${reqoperstatus}'!='${EMPTY}'       ${reqoperstatus}       ${oper_status}
    ${connect_status}=    Set Variable If    '${reqconnectstatus}'!='${EMPTY}'    ${reqconnectstatus}
    ...    ${connect_status}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration
    ...    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${onu_state}    ${list_onus}    ${timeStart}    alternate_reason=${alternativeonustate}

Do Current Reason Test All Onus
    [Documentation]    This keyword checks the passed state of all onus.
    ...                Hint: ${timeStart} will be not evaluated here!
    [Arguments]    ${state}
    ${list_onus}    Create List
    Build ONU SN List    ${list_onus}    ${olt_serial_number}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=    Map State    ${state}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    ${onu_state}    ${list_onus}    ${timeStart}

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

Verify MIB Template Data Available
    [Documentation]    This keyword verifies MIB Template Data stored in etcd
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commandget}
    Should Not Be Empty    ${result}    No MIB Template Data stored in etcd!

Delete MIB Template Data
    [Documentation]    This keyword deletes MIB Template Data stored in etcd
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${commanddel}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commanddel}
    Sleep    3s
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commandget}
    Should Be Empty    ${result}    Could not delete MIB Template Data stored in etcd!

Validate Onu Data In Etcd
    [Documentation]    This keyword validates openonu-go-adapter Data stored in etcd.
    ...                It checks unique of  serial_number and combination of pon, onu and uni in tp_path.
    ...                Furthermore it evaluates the values of onu_id and uni_id with values read from tp_path.
    ...                Number of etcd entries has to match with the passed number.
    [Arguments]    ${nbofetcddata}=${num_all_onus}
    ${etcddata}=    Get ONU Go Adapter ETCD Data
    ${etcddata}=    Remove Lines Containing String    ${etcddata}    service/voltha/openonu    \n
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
        ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]}    tp_path
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
    ${etcddata}=    Get ONU Go Adapter ETCD Data
    ${etcddata}=    Remove Lines Containing String    ${etcddata}    service/voltha/openonu    \n
    #prepare result for json convert
    ${result}=    Prepare ONU Go Adapter ETCD Data For Json    ${etcddata}
    ${jsondata}=    To Json    ${result}
    ${length}=    Get Length    ${jsondata}
    log    ${jsondata}
    ${vlan_rules}=    Create Dictionary
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]}    tp_path
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
    log Many   ${vlan_rules}
    [Return]    ${vlan_rules}

Get ONU Go Adapter ETCD Data
    [Documentation]    This keyword delivers openonu-go-adapter Data stored in etcd
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix --prefix service/voltha/openonu'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commandget}
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
    ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]}    tp_path
    ${tppathlines}=   Replace String    ${tp_path}    /    \n
    ${onu}=    Get Value Of Tp Path Element    ${tppathlines}    onu
    ${onu_id}=    Get From Dictionary    ${value}    onu_id
    Should Be Equal As Integers    ${onu}    ${onu_id}
    ...    msg=Onu-Id (${onu_id}) does not match onu (${onu}) from tp_path in etcd data!
    Should Be True    ${onu_id}>=1

Validate Uni Id
    [Documentation]    This keyword validates UNI Id of passed etcd data.
    [Arguments]    ${value}
    ${tp_path}=    Get From Dictionary    ${value['uni_config'][0]}    tp_path
    ${tppathlines}=   Replace String    ${tp_path}    /    \n
    ${uni}=    Get Value Of Tp Path Element    ${tppathlines}    uni
    ${uni_id}=    Get From Dictionary    ${value['uni_config'][0]}    uni_id
    Should Be Equal As Integers    ${uni}    ${uni_id}
    ...    msg=Uni-Id (${uni_id}) does not match onu (${uni}) from tp_path in etcd data!

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
