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
    Build ONU SN List    ${list_onus}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=    Map State    ${state}
    ${admin_state}=       Set Variable If    '${reqadminstate}'!='${EMPTY}'       ${reqadminstate}       ${admin_state}
    ${oper_status}=       Set Variable If    '${reqoperstatus}'!='${EMPTY}'       ${reqoperstatus}       ${oper_status}
    ${connect_status}=    Set Variable If    '${reqconnectstatus}'!='${EMPTY}'    ${reqconnectstatus}
    ...    ${connect_status}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration
    ...    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${onu_state}    ${list_onus}    ${timeStart}    alternate_reason=${alternativeonustate)

Do Current Reason Test All Onus
    [Documentation]    This keyword checks the passed state of all onus.
    ...                Hint: ${timeStart} will be not evaluated here!
    [Arguments]    ${state}
    ${list_onus}    Create List
    Build ONU SN List    ${list_onus}
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
