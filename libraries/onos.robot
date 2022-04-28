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
# onos common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Resource          ./flows.robot

*** Variables ***
@{connection_list}
${alias}                  ONOS_SSH
${ssh_read_timeout}       60s
${ssh_prompt}             karaf@root >
${ssh_regexp_prompt}      REGEXP:k.*a.*r.*a.*f.*@.*r.*o.*o.*t.* .*>.*
${regexp_prompt}          k.*a.*r.*a.*f.*@.*r.*o.*o.*t.* .*>.*
${ssh_width}              400
${disable_highlighter}    setopt disable-highlighter
# ${keep_alive_interval} is set to 0s means sending the keepalive packet is disabled!
${keep_alive_interval}    0s

@{http_connection_list}
${http_alias}                  ONOS

*** Keywords ***

Open ONOS SSH Connection
    [Documentation]    Establishes an ssh connection to ONOS contoller
    [Arguments]    ${host}    ${port}    ${user}=karaf    ${pass}=karaf
    ${conn_id}=    SSHLibrary.Open Connection    ${host}    port=${port}    timeout=${ssh_read_timeout}    alias=${alias}
    SSHLibrary.Login    username=${user}    password=${pass}    keep_alive_interval=${keep_alive_interval}
    # set excepted prompt and terminal width to suppress unwanted line feeds
    SSHLibrary.Set Client Configuration    prompt=${ssh_prompt}    width=${ssh_width}
    ${conn_list_entry}=    Create Dictionary    conn_id=${conn_id}    user=${user}    pass=${pass}
    ...    host=${host}    port=${port}    alias=${alias}
    Append To List    ${connection_list}    ${conn_list_entry}
    ${conn_list_id}=    Get Index From List    ${connection_list}    ${conn_list_entry}
    Set Global Variable    ${connection_list}
    # disable highlighting to suppress control sequences
    ${output}=    Execute Single ONOS CLI Command    ${conn_id}    ${disable_highlighter}    do_reconnect=False
    [Return]    ${conn_list_id}

Execute ONOS CLI Command use single connection
    [Documentation]    Execute ONOS CLI Command use an Open Connection
    ...                In case no connection is open a connection will be opened
    ...                Using Write and Read instead of Execute Command to keep connection alive.
    [Arguments]    ${host}    ${port}    ${cmd}
    ${connection_list_id}=    Get Conn List Id    ${host}    ${port}
    ${connection_list_id}=    Run Keyword If    "${connection_list_id}"=="${EMPTY}"
                              ...    Open ONOS SSH Connection    ${host}    ${port}
                              ...    ELSE    Set Variable    ${connection_list_id}
    ${connection_entry}=    Get From List   ${connection_list}    ${connection_list_id}
    ${output}=    Execute Single ONOS CLI Command    ${connection_entry.conn_id}    ${cmd}
    ...           connection_list_id=${connection_list_id}
    [Return]    ${output}

Execute Single ONOS CLI Command
    [Documentation]    Executes ONOS CLI Command on current connection
    ...                Using Write and Read instead of Execute Command to keep connection alive.
    [Arguments]    ${conn_id}    ${cmd}    ${do_reconnect}=True    ${connection_list_id}=${EMPTY}
    Log    Command: ${cmd}
    SSHLibrary.Switch Connection   ${conn_id}
    # get connection settings, has no functional reason, only for info
    ${connection_info}=    SSHLibrary.Get Connection
    # write the command until it is mirrored
    ${PassOrFail}    ${Written}=    Run Keyword And Ignore Error    Write Until Expected Output    ${cmd}    expected=${cmd}
    ...              timeout=5s    retry_interval=1s
    Run Keyword If    '${PassOrFail}'=='FAIL' and ${do_reconnect}    Reconnect ONOS SSH Connection    ${connection_list_id}
    Run Keyword If    '${PassOrFail}'=='FAIL'    Write Until Expected Output    ${cmd}${\n}    expected=${cmd}    timeout=5s
    ...               retry_interval=1s
    # set up the comand - press enter key!
    ${Written}=    Write    ${EMPTY}
    ${PassOrFail}    ${output}=    Run Keyword And Ignore Error    Read Until Prompt    strip_prompt=True
    Log    Result_values: ${output}
    # remove error printout from ssh library in case of failure
    ${output}=    Run Keyword If    '${PassOrFail}'=='FAIL'    Fetch From Right    ${output}    Output:
    ...           ELSE    Set Variable   ${output}
    ${output}=    Run Keyword If    '${PassOrFail}'=='FAIL'    Get Substring    ${output}    1
    ...           ELSE    Set Variable   ${output}
    ${output_length}=    Get Length    ${output}
    # remove regexp-prompt if available
    ${output}=    Remove String Using Regexp    ${output}    ${regexp_prompt}
    ${output_after}=    Get Length    ${output}
    Run Keyword If    '${PassOrFail}'=='FAIL' and ${output_length}== ${output_after}  FAIL    SSH access failed for '${cmd}'!
    # we do not use strip of escape sequences integrated in ssh lib, we do it by ourself to have it under control
    ${output}=    Remove String Using Regexp    ${output}    \\x1b[>=]{0,1}(?:\\[[0-?]*(?:[hlm])[~]{0,1})*
    # remove the endless spaces and two carrige returns at the end of output
    ${output}=    Remove String Using Regexp    ${output}    \\s*\\r \\r
    # now we have the plain output text
    Log    Stripped Result_values: ${output}
    [Return]    ${output}

Get Conn List Id
    [Documentation]    Looks up for an Open Connection with passed host and port in conection list
    ...                First match connection will be used.
    [Arguments]    ${host}    ${port}
    ${connection_list_id}=    Set Variable    ${EMPTY}
    ${match}=     Set Variable    False
    ${length}=    Get Length    ${connection_list}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        #${Item}=    Get From List    ${connection_list}    ${INDEX}
        ${conndata}=    Get Connection    ${connection_list[${INDEX}].conn_id}
        ${match}=    Set Variable If    '${conndata.host}'=='${host}' and '${conndata.port}'=='${port}'    True    False
        ${connection_list_id}=    Set Variable If    ${match}    ${INDEX}    ${EMPTY}
        Exit For Loop If    ${match}
    END
    [Return]    ${connection_list_id}

Reconnect ONOS SSH Connection
    [Documentation]    Reconnect an SSH Connection
    [Arguments]    ${connection_list_id}
    ${connection_entry}=    Get From List   ${connection_list}    ${connection_list_id}
    ${user}=    Get From Dictionary    ${connection_entry}    user
    ${pass}=    Get From Dictionary    ${connection_entry}    pass
    ${oldconndata}=    Get Connection    ${connection_entry.conn_id}
    ${match}=    Set Variable If
    ...    "${oldconndata.host}"=="${connection_entry.host}" and "${oldconndata.port}"=="${connection_entry.port}"
    ...    True    False
    Run Keyword If    ${match}    SSHLibrary.Switch Connection   ${connection_entry.conn_id}
    Run Keyword If    ${match}    Run Keyword And Ignore Error    SSHLibrary.Close Connection
    ${conn_id}=    SSHLibrary.Open Connection    ${connection_entry.host}    port=${connection_entry.port}
    ...    timeout=${ssh_read_timeout}    alias=${alias}
    SSHLibrary.Login    username=${user}    password=${pass}    keep_alive_interval=${keep_alive_interval}
    # set excepted prompt and terminal width to suppress unwanted line feeds
    SSHLibrary.Set Client Configuration    prompt=${ssh_prompt}    width=${ssh_width}
    ${conn_list_entry}=    Create Dictionary    conn_id=${conn_id}    user=${user}    pass=${pass}
    ...    host=${connection_entry.host}    port=${connection_entry.port}    alias=${alias}
    Set List Value    ${connection_list}    ${connection_list_id}    ${conn_list_entry}
    Set Global Variable    ${connection_list}
    # disable highlighting to suppress control sequences
    ${output}=    Execute Single ONOS CLI Command    ${conn_id}    ${disable_highlighter}    do_reconnect=False

Close ONOS SSH Connection
    [Documentation]    Close an SSH Connection
    [Arguments]    ${connection_list_id}
    ${connection_entry}=    Get From List   ${connection_list}    ${connection_list_id}
    ${connection_alias}=    Get From Dictionary    ${connection_entry}    conn_id
    ${oldconndata}=    Get Connection    ${connection_entry.conn_id}
    SSHLibrary.Switch Connection   ${connection_alias}
    Run Keyword And Ignore Error    SSHLibrary.Close Connection
    Remove From List    ${connection_list}    ${connection_list_id}
    Set Global Variable    ${connection_list}

Close All ONOS SSH Connections
    [Documentation]    Close all SSH Connection and clear connection list.
    SSHLibrary.Close All Connections
    @{connection_list}    Create List


Open ONOS HTTP Session
    [Documentation]    Establishes an http session to ONOS contoller
    [Arguments]    ${host}    ${port}    ${user}=karaf    ${pass}=karaf
    ${onos_auth}=    Create List    ${user}    ${pass}
    Create Session    ${http_alias}    http://${host}:${port}    auth=${onos_auth}
    ${conn_list_entry}=    Create Dictionary    alias=${http_alias}    user=${user}    pass=${pass}
    ...    host=${host}    port=${port}
    Append To List    ${http_connection_list}    ${conn_list_entry}
    ${conn_list_id}=    Get Index From List    ${http_connection_list}    ${conn_list_entry}
    Set Global Variable    ${http_connection_list}
    [Return]    ${conn_list_id}

Execute ONOS Rest API Request use single session
    [Documentation]    Execute ONOS Rest API Request use an open HTTP session
    ...                In case no HTTP session is open a session will be established
    [Arguments]    ${host}    ${port}    ${request}    ${url}
    ${connection_list_id}=    Get HTTP Conn List Id    ${host}    ${port}
    ${connection_list_id}=    Run Keyword If    "${connection_list_id}"=="${EMPTY}"
                              ...    Open ONOS HTTP Session    ${host}    ${port}
                              ...    ELSE    Set Variable    ${connection_list_id}
    ${connection_entry}=    Get From List   ${http_connection_list}    ${connection_list_id}
    ${session_exists}=    Session Exists    ${connection_entry.alias}
    Run Keyword If    not ${session_exists}   Reconnect ONOS HTTP Session    ${connection_list_id}
    ${output}=    Execute Single ONOS Rest API Request    ${connection_entry.alias}    ${request}    ${url}
    ...           connection_list_id=${connection_list_id}
    [Return]    ${output}

Execute Single ONOS Rest API Request
    [Documentation]    Executes ONOS Rest API Request
    [Arguments]    ${alias}    ${request}    ${url}    ${connection_list_id}=${EMPTY}
    Log    Request: ${request} Url: ${url}
    ${resp}=    Run Keyword If    "${request}"=="GET"      GET On Session        ${alias}    ${url}    expected_status=Anything
    ...                ELSE IF    "${request}"=="POST"     POST On Session       ${alias}    ${url}    expected_status=Anything
    ...                ELSE IF    "${request}"=="PUT"      PUT On Session        ${alias}    ${url}    expected_status=Anything
    ...                ELSE IF    "${request}"=="DELETE"   DELETE On Session     ${alias}    ${url}    expected_status=Anything
    ...                ELSE IF    "${request}"=="HEAD"     HEAD On Session       ${alias}    ${url}    expected_status=Anything
    ...                ELSE IF    "${request}"=="OPTIONS"  OPTIONS On Session    ${alias}    ${url}    expected_status=Anything
    ...                ELSE IF    "${request}"=="PATCH"    PATCH On Session      ${alias}    ${url}    expected_status=Anything
    ...                ELSE       FAIL    Unknown request "${request}"!
    [Return]    ${resp.json()}

Get HTTP Conn List Id
    [Documentation]    Looks up for an existing session with passed host and port in conection list
    ...                First match connection will be used.
    [Arguments]    ${host}    ${port}
    ${connection_list_id}=    Set Variable    ${EMPTY}
    ${match}=     Set Variable    False
    ${length}=    Get Length    ${http_connection_list}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${Item}=    Get From List    ${http_connection_list}    ${INDEX}
        ${match}=    Set Variable If    '${Item.host}'=='${host}' and '${Item.port}'=='${port}'    True    False
        ${connection_list_id}=    Set Variable If    ${match}    ${INDEX}    ${EMPTY}
        Exit For Loop If    ${match}
    END
    [Return]    ${connection_list_id}

Reconnect ONOS HTTP Session
    [Documentation]    Reconnect an SSH Connection
    [Arguments]    ${connection_list_id}
    ${connection_entry}=    Get From List   ${http_connection_list}    ${connection_list_id}
    ${user}=    Get From Dictionary    ${connection_entry}    user
    ${pass}=    Get From Dictionary    ${connection_entry}    pass
    ${host}=    Get From Dictionary    ${connection_entry}    host
    ${port}=    Get From Dictionary    ${connection_entry}    port
    ${alias}=   Get From Dictionary    ${connection_entry}    alias
    ${onos_auth}=    Create List    ${user}    ${pass}
    Create Session    ${alias}    http://${host}:${port}    auth=${onos_auth}
    ${conn_list_entry}=    Create Dictionary    alias=${alias}    user=${user}    pass=${pass}
    ...    host=${connection_entry.host}    port=${connection_entry.port}
    Set List Value    ${http_connection_list}    ${connection_list_id}    ${conn_list_entry}
    Set Global Variable    ${http_connection_list}

Close All ONOS HTTP Sessions
    [Documentation]    Close all HTTP Sessions and clear connection list.
    Delete All Sessions
    @{http_connection_list}    Create List

Validate OLT Device in ONOS
    #    FIXME use volt-olts to check that the OLT is ONOS
    [Arguments]    ${serial_number}
    [Documentation]    Checks if olt has been connected to ONOS
    ${jsondata}=   Execute ONOS Rest API Request use single session   ${ONOS_REST_IP}   ${ONOS_REST_PORT}   GET   onos/v1/devices
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    @{serial_numbers}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${sn}=    Get From Dictionary    ${value}    serial
        ${matched}=    Set Variable If    '${sn}' == '${serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${serial_number} found
    [Return]    ${of_id}

Get ONU Port in ONOS
    [Arguments]    ${onu_serial_number}    ${olt_of_id}    ${onu_uni_id}=1
    [Documentation]    Retrieves ONU port for the ONU in ONOS
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_serial_number}    ${onu_uni_id}
    ${jsondata}=   Execute ONOS Rest API Request use single session   ${ONOS_REST_IP}   ${ONOS_REST_PORT}   GET
    ...    onos/v1/devices/${olt_of_id}/ports
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${onu_port}=    Get From Dictionary    ${value}    port
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${matched}=    Set Variable If    '${portName}' == '${onu_serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${onu_serial_number} found
    [Return]    ${onu_port}

Get Onu Ports in ONOS For ALL UNI per ONU
    [Documentation]    Retrieves ONU port(s) for the ONU in ONOS for all UNI-IDs, list of ports will return!
    [Arguments]    ${onu_serial_number}    ${olt_of_id}
    @{uni_id_list}=    Create List
    @{port_list}=      Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${src['onu']}" != "${onu_serial_number}"
        ${uni_id}=    Set Variable    ${src['uni_id']}
        # make sure all actions do only once per uni_id
        ${id}=    Get Index From List    ${uni_id_list}   ${uni_id}
        Continue For Loop If    -1 != ${id}
        Append To List    ${uni_id_list}    ${uni_id}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${onu_serial_number}
        ...    ${olt_of_id}    ${uni_id}
        Append To List    ${port_list}    ${onu_port}
    END
    [return]    ${port_list}

Get NNI Port in ONOS
    [Arguments]    ${olt_of_id}
    [Documentation]    Retrieves NNI port for the OLT in ONOS
    ${jsondata}=   Execute ONOS Rest API Request use single session   ${ONOS_REST_IP}   ${ONOS_REST_PORT}   GET
    ...    onos/v1/devices/${olt_of_id}/ports
    Should Not Be Empty    ${jsondata['ports']}
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${nni_port}=    Get From Dictionary    ${value}    port
        ${nniPortName}=    Catenate    SEPARATOR=    nni-    ${nni_port}
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${matched}=    Set Variable If    '${portName}' == '${nniPortName}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for NNI found for ${olt_of_id}
    [Return]    ${nni_port}

Get FabricSwitch in ONOS
    [Documentation]    Returns of_id of the Fabric Switch in ONOS
    ${jsondata}=   Execute ONOS Rest API Request use single session   ${ONOS_REST_IP}   ${ONOS_REST_PORT}   GET   onos/v1/devices
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${type}=    Get From Dictionary    ${value}    type
        ${matched}=    Set Variable If    '${type}' == "SWITCH"    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No fabric switch found
    [Return]    ${of_id}

Get Master Instace in ONOS
    [Arguments]    ${of_id}
    [Documentation]    Returns nodeId of the Master instace for a giver device in ONOS
    ${jsondata}=   Execute ONOS Rest API Request use single session   ${ONOS_REST_IP}   ${ONOS_REST_PORT}   GET
    ...    onos/v1/mastership/${of_id}/master
    Should Not Be Empty    ${jsondata['nodeId']}
    ${master_node}=    Get From Dictionary    ${jsondata}    nodeId
    [Return]    ${master_node}

Verify LLDP Flow Added
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${expected_flows}
    [Documentation]    Matches for total number of LLDP flows added for one OLT
    ${lldp_flows_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep -v deviceId | grep ETH_TYPE:lldp | grep -v ETH_TYPE:arp
    ${lldp_flows_added_count}=      Get Line Count      ${lldp_flows_added}
    Should Be Equal As Integers    ${lldp_flows_added_count}    ${expected_flows}

Verify Subscriber Access Flows Added for ONU
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${c_tag}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:0 |
    ...     grep VLAN_ID:${c_tag} | grep transition=TABLE:1
    ${upstream_flow_0_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${upstream_flow_0_cmd}
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_ID:0 | grep OUTPUT:${onu_port}
    ${downstream_flow_1_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${downstream_flow_1_cmd}
    Should Not Be Empty    ${downstream_flow_1_added}
    # Verify ipv4 dhcp upstream flow
    ${upstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep ETH_TYPE:ipv4 |
    ...     grep IP_PROTO:17 | grep UDP_SRC:68 | grep UDP_DST:67 | grep VLAN_ID:${c_tag} |
    ...     grep OUTPUT:CONTROLLER
    ${upstream_flow_ipv4_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${upstream_flow_ipv4_cmd}
    Should Not Be Empty    ${upstream_flow_ipv4_added}
    # Verify ipv4 dhcp downstream flow
    # Note: This flow will be one per nni per olt
    ${downstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep ETH_TYPE:ipv4 |
    ...     grep IP_PROTO:17 | grep UDP_SRC:67 | grep UDP_DST:68 | grep OUTPUT:CONTROLLER
    ${downstream_flow_ipv4_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${downstream_flow_ipv4_cmd}
    Should Not Be Empty    ${downstream_flow_ipv4_added}

Verify Subscriber Access Flows Added for ONU DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any | grep transition=TABLE:1
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:Any | grep OUTPUT:${onu_port}
    Should Not Be Empty    ${downstream_flow_1_added}

Verify Subscriber Access Flows Added for DT FTTB
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}    ${c_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Upstream
    # ONU
    ${us_flow_onu_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} | grep transition=TABLE:1
    Should Not Be Empty    ${us_flow_onu_added}
    # OLT
    ${us_flow_olt_cmd}=    Catenate
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} |
    ...    grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${us_flow_olt_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${us_flow_olt_cmd}
    Should Not Be Empty    ${us_flow_olt_added}
    # Downstream
    # OLT
    ${ds_flow_olt_cmd}=    Catenate
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...    grep VLAN_ID:${c_tag} | grep transition=TABLE:1
    ${ds_flow_olt_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${ds_flow_olt_cmd}
    Should Not Be Empty    ${ds_flow_olt_added}
    # ONU
    ${ds_flow_onu_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${c_tag} | grep OUTPUT:${onu_port}
    Should Not Be Empty    ${ds_flow_onu_added}

Verify DPU ANCP Flows Added for DT FTTB
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}    ${c_tag}
    [Documentation]    Verifies if the DPU ANCP Flows are added in ONOS for the ONU
    # Upstream
    # ONU
    ${us_flow_onu_cmd}=    Catenate
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} |
    ...    grep VLAN_ID:${s_tag} | grep transition=TABLE:1
    ${us_flow_onu_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${us_flow_onu_cmd}
    Should Not Be Empty    ${us_flow_onu_added}
    # OLT
    ${us_flow_olt_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${s_tag} | grep OUTPUT:${nni_port}
    Should Not Be Empty    ${us_flow_olt_added}
    # Downstream
    # OLT
    ${ds_flow_olt_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} | grep transition=TABLE:1
    Should Not Be Empty    ${ds_flow_olt_added}
    # ONU
    ${ds_flow_onu_cmd}=    Catenate
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...    grep VLAN_ID:${c_tag} | grep OUTPUT:${onu_port}
    ${ds_flow_onu_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${ds_flow_onu_cmd}
    Should Not Be Empty    ${ds_flow_onu_added}

Verify DPU MGMT Flows Added for DT FTTB
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}    ${c_tag}
    [Documentation]    Verifies if the DPU MGMT Flows are added in ONOS for the ONU
    # Upstream
    # ONU
    ${us_flow_onu_cmd}=    Catenate
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} |
    ...    grep VLAN_ID:${s_tag} | grep transition=TABLE:1
    ${us_flow_onu_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${us_flow_onu_cmd}
    Should Not Be Empty    ${us_flow_onu_added}
    # OLT
    ${us_flow_olt_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${s_tag} | grep OUTPUT:${nni_port}
    Should Not Be Empty    ${us_flow_olt_added}
    # Downstream
    # OLT
    ${ds_flow_olt_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} | grep transition=TABLE:1
    Should Not Be Empty    ${ds_flow_olt_added}
    # ONU
    ${ds_flow_onu_cmd}=    Catenate
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...    grep VLAN_ID:${c_tag} | grep OUTPUT:${onu_port}
    ${ds_flow_onu_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${ds_flow_onu_cmd}
    Should Not Be Empty    ${ds_flow_onu_added}

Verify ONOS Flows Added for DT FTTB
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${service}
    [Documentation]    Verifies if the Flows are added in ONOS for the ONU
    ${num_services}=    Get Length    ${service}
    FOR     ${I}    IN RANGE    0    ${num_services}
        ${service_name}=    Set Variable    ${service[${I}]['name']}
        ${stag}=    Set Variable    ${service[${I}]['s_tag']}
        ${ctag}=    Set Variable    ${service[${I}]['c_tag']}
        Run Keyword If    '${service_name}' == 'FTTB_SUBSCRIBER_TRAFFIC'
        ...    Verify Subscriber Access Flows Added for DT FTTB    ${ip}    ${port}
        ...    ${olt_of_id}    ${onu_port}    ${nni_port}    ${stag}    ${ctag}
        ...    ELSE IF    '${service_name}' == 'DPU_ANCP_TRAFFIC'
        ...    Verify DPU ANCP Flows Added for DT FTTB    ${ip}    ${port}
        ...    ${olt_of_id}    ${onu_port}    ${nni_port}    ${stag}    ${ctag}
        ...    ELSE IF    '${service_name}' == 'DPU_MGMT_TRAFFIC'
        ...    Verify DPU MGMT Flows Added for DT FTTB    ${ip}    ${port}
        ...    ${olt_of_id}    ${onu_port}    ${nni_port}    ${stag}    ${ctag}
    END

Verify Subscriber Access Flows Added Count DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${expected_flows}
    [Documentation]    Matches for total number of subscriber access flows added for all onus
    ${access_flows_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep -v deviceId | grep -v ETH_TYPE:lldp | grep -v ETH_TYPE:arp
    ${access_flows_added_count}=      Get Line Count      ${access_flows_added}
    Should Be Equal As Integers    ${access_flows_added_count}    ${expected_flows}

Verify Added Flow Count for OLT TT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${expected_flows}
    [Documentation]    Total number of added flows given OLT with subscriber flows
    ${access_flows_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep -v deviceId
    ${access_flows_added_count}=      Get Line Count      ${access_flows_added}
    Should Be Equal As Integers    ${access_flows_added_count}    ${expected_flows}

Verify Default Downstream Flows are added in ONOS for OLT TT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${nni_port}
    [Documentation]    Verifies if the Default Downstream Flows are added in ONOS for the OLT
    # Verify lldp flow
    ${downstream_flow_lldp_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep lldp |
    ...     grep OUTPUT:CONTROLLER
    ${downstream_flow_lldp_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${downstream_flow_lldp_cmd}
    Should Not Be Empty    ${downstream_flow_lldp_added}
    # Verify downstream dhcp flow
    ${downstream_flow_dhcp_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IP_PROTO:17 | grep UDP_SRC:67 | grep UDP_DST:68 |
    ...     grep OUTPUT:CONTROLLER
    ${downstream_flow_dhcp_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${downstream_flow_dhcp_cmd}
    Should Not Be Empty    ${downstream_flow_dhcp_added}
    # Verify downstream igmp flow
    ${downstream_flow_igmp_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IP_PROTO:2 |
    ...     grep OUTPUT:CONTROLLER
    ${downstream_flow_igmp_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${downstream_flow_igmp_cmd}
    Should Not Be Empty    ${downstream_flow_igmp_added}

Get Programmed Subscribers
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${filter}=${EMPTY}
    [Documentation]    Retrieves the subscriber details at a given location
    ${cmd}=    Set Variable If    '${filter}' == '${EMPTY}'
    ...    volt-programmed-subscribers ${olt_of_id} ${onu_port}
    ...    volt-programmed-subscribers ${olt_of_id} ${onu_port} | grep ${filter} --color=none
    ${programmed_sub}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}    ${cmd}
    [Return]    ${programmed_sub}

Verify Programmed Subscribers DT FTTB
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${service}
    [Documentation]    Verifies the subscriber is present at a given location
    ${num_services}=    Get Length    ${service}
    FOR    ${I}    IN RANGE    0    ${num_services}
        ${service_name}=    Set Variable    ${service[${I}]['name']}
        ${programmed_subscriber}=    Get Programmed Subscribers    ${ip}    ${port}    ${olt_of_id}    ${onu_port}
        ...    ${service_name}
        Log    ${programmed_subscriber}
        Should Not Be Empty    ${programmed_subscriber}
    END

Get Upstream and Downstream Bandwidth Profile Name
    [Arguments]    ${programmed_sub}
    [Documentation]    Retrieves the upstream and downstream bandwidth profile name
    ...    from the programmed subscriber
    @{programmed_sub_array}=    Split String    ${programmed_sub}    ,
    # Get upstream bandwidth profile name for the subscriber
    @{param_val_pair}=    Split String    ${programmed_sub_array[9]}    =
    ${programmed_sub_param}=    Set Variable    ${param_val_pair[0]}
    ${programmed_sub_val}=    Set Variable    ${param_val_pair[1]}
    ${us_bw_profile}=    Run Keyword If    '${programmed_sub_param}' == ' upstreamBandwidthProfile'
    ...    Set Variable    ${programmed_sub_val}
    Log    ${us_bw_profile}
    # Get downstream bandwidth profile name for the subscriber
    @{param_val_pair}=    Split String    ${programmed_sub_array[10]}    =
    ${programmed_sub_param}=    Set Variable    ${param_val_pair[0]}
    ${programmed_sub_val}=    Set Variable    ${param_val_pair[1]}
    ${ds_bw_profile}=    Run Keyword If    '${programmed_sub_param}' == ' downstreamBandwidthProfile'
    ...    Set Variable    ${programmed_sub_val}
    Log    ${ds_bw_profile}
    [Return]    ${us_bw_profile}    ${ds_bw_profile}

Get Bandwidth Profile Details
    [Arguments]    ${ip}    ${port}    ${bw_profile}
    [Documentation]    Retrieves the details of the given bandwidth profile
    ${bw_profile_values}=    Execute ONOS CLI Command use single connection   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    bandwidthprofile ${bw_profile}
    @{bw_profile_array}=    Split String    ${bw_profile_values}    ,
    @{param_val_pair}=    Split String    ${bw_profile_array[1]}    =
    ${bw_param}=    Set Variable    ${param_val_pair[0]}
    ${bw_val}=    Set Variable    ${param_val_pair[1]}
    ${cir}    Run Keyword If    '${bw_param}' == ' committedInformationRate'
    ...    Set Variable    ${bw_val}
    @{param_val_pair}=    Split String    ${bw_profile_array[2]}    =
    ${bw_param}=    Set Variable    ${param_val_pair[0]}
    ${bw_val}=    Set Variable    ${param_val_pair[1]}
    ${cbs}    Run Keyword If    '${bw_param}' == ' committedBurstSize'
    ...    Set Variable    ${bw_val}
    @{param_val_pair}=    Split String    ${bw_profile_array[3]}    =
    ${bw_param}=    Set Variable    ${param_val_pair[0]}
    ${bw_val}=    Set Variable    ${param_val_pair[1]}
    ${eir}    Run Keyword If    '${bw_param}' == ' exceededInformationRate'
    ...    Set Variable    ${bw_val}
    @{param_val_pair}=    Split String    ${bw_profile_array[4]}    =
    ${bw_param}=    Set Variable    ${param_val_pair[0]}
    ${bw_val}=    Set Variable    ${param_val_pair[1]}
    ${ebs}    Run Keyword If    '${bw_param}' == ' exceededBurstSize'
    ...    Set Variable    ${bw_val}
    @{param_val_pair}=    Split String    ${bw_profile_array[5]}    =
    ${bw_param}=    Set Variable    ${param_val_pair[0]}
    ${bw_val}=    Set Variable    ${param_val_pair[1]}
    @{bw_val_air}=    Split String    ${bw_val}    }
    ${air}    Run Keyword If    '${bw_param}' == ' assuredInformationRate'
    ...    Set Variable    ${bw_val_air[0]}
    [Return]    ${cir}    ${cbs}    ${eir}    ${ebs}    ${air}

Get Bandwidth Profile Details Rest
    [Arguments]    ${bw_profile_id}
    [Documentation]    Retrieves the details of the given bandwidth profile using REST API
    ${bw_profile_id}=    Remove String    ${bw_profile_id}    '    "
    ${resp}=    Get Request    ONOS    onos/sadis/bandwidthprofile/${bw_profile_id}
    ${jsondata}=    ${resp.json()}
    Should Not Be Empty    ${jsondata['entry']}
    ${length}=    Get Length    ${jsondata['entry']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['entry']}    ${INDEX}
        ${bw_id}=    Get From Dictionary    ${value}    id
        ${matched}=    Set Variable If    '${bw_id}' == '${bw_profile_id}'    True    False
        ${eir}=    Get From Dictionary    ${value}    eir
        ${ebs}=    Get From Dictionary    ${value}    ebs
        ${cir}=    Get From Dictionary    ${value}    cir
        ${cbs}=    Get From Dictionary    ${value}    cbs
        ${air}=    Get From Dictionary    ${value}    air
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No bandwidth profile found for id: ${bw_profile_id}
    [Return]    ${cir}    ${cbs}    ${eir}    ${ebs}    ${air}

Get Bandwidth Profile Details Ietf Rest
    [Arguments]    ${bw_profile_id}
    [Documentation]    Retrieves the details of the given Ietf standard based bandwidth profile using REST API
    ${bw_profile_id}=    Remove String    ${bw_profile_id}    '    "
    ${resp}=    Get Request    ONOS    onos/sadis/bandwidthprofile/${bw_profile_id}
    ${jsondata}=    ${resp.json()}
    Should Not Be Empty    ${jsondata['entry']}
    ${length}=    Get Length    ${jsondata['entry']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['entry']}    ${INDEX}
        ${bw_id}=    Get From Dictionary    ${value}    id
        ${matched}=    Set Variable If    '${bw_id}' == '${bw_profile_id}'    True    False
        ${pir}=    Get From Dictionary    ${value}    pir
        ${pbs}=    Get From Dictionary    ${value}    pbs
        ${cir}=    Get From Dictionary    ${value}    cir
        ${cbs}=    Get From Dictionary    ${value}    cbs
        ${gir}=    Get From Dictionary    ${value}    gir
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No bandwidth profile found for id: ${bw_profile_id}
    [Return]    ${cir}    ${cbs}    ${pir}    ${pbs}    ${gir}

Verify Meters in ONOS Ietf
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${filter}=${EMPTY}
    [Documentation]    Verifies the meters with BW Ietf format (currently, DT workflow uses this format)
    # Get programmed subscriber
    ${programmed_sub}=    Get Programmed Subscribers    ${ip}    ${port}
    ...    ${olt_of_id}    ${onu_port}    ${filter}
    Log    ${programmed_sub}
    ${us_bw_profile}    ${ds_bw_profile}    Get Upstream and Downstream Bandwidth Profile Name
    ...    ${programmed_sub}
    # Get upstream bandwidth profile details
    ${us_cir}    ${us_cbs}    ${us_pir}    ${us_pbs}    ${us_gir}    Get Bandwidth Profile Details Ietf Rest
    ...    ${us_bw_profile}
    # Verify meter for upstream bandwidth profile
    ${us_meter_cmd}=    Run Keyword If    ${us_gir} != 0    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${us_cir}, burst-size=${us_cbs}"
    ...     | grep "rate=${us_pir}, burst-size=${us_pbs}" | grep "rate=${us_gir}, burst-size=0" | wc -l
    ...    ELSE    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${us_cir}, burst-size=${us_cbs}"
    ...     | grep "rate=${us_pir}, burst-size=${us_pbs}" | wc -l
    ${upstream_meter_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${us_meter_cmd}
    Should Be Equal As Integers    ${upstream_meter_added}    1   Upstream meter is missing
    # Get downstream bandwidth profile details
    ${ds_cir}    ${ds_cbs}    ${ds_pir}    ${ds_pbs}    ${ds_gir}    Get Bandwidth Profile Details Ietf Rest
    ...    ${ds_bw_profile}
    # Verify meter for downstream bandwidth profile
    ${ds_meter_cmd}=    Run Keyword If    ${ds_gir} != 0    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${ds_cir}, burst-size=${ds_cbs}"
    ...     | grep "rate=${ds_pir}, burst-size=${ds_pbs}" | grep "rate=${ds_gir}, burst-size=0" | wc -l
    ...    ELSE    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${ds_cir}, burst-size=${ds_cbs}"
    ...     | grep "rate=${ds_pir}, burst-size=${ds_pbs}" | wc -l
    ${downstream_meter_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${ds_meter_cmd}
    Should Be Equal As Integers    ${downstream_meter_added}    1   Downstream meter is missing

Verify Meters in ONOS
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}
    [Documentation]    Verifies the meters
    # Get programmed subscriber
    ${programmed_sub}=    Get Programmed Subscribers    ${ip}    ${port}
    ...    ${olt_of_id}    ${onu_port}
    Log    ${programmed_sub}
    ${us_bw_profile}    ${ds_bw_profile}    Get Upstream and Downstream Bandwidth Profile Name
    ...    ${programmed_sub}
    # logging all meters to facilitate debug
    ${all_meters}=      Execute ONOS CLI Command use single connection    ${ip}    ${port}      meters
    Log     ${all_meters}
    # Get upstream bandwidth profile details
    ${us_cir}    ${us_cbs}    ${us_eir}    ${us_ebs}    ${us_air}    Get Bandwidth Profile Details
    ...    ${ip}    ${port}    ${us_bw_profile}
    Sleep    1s
    ${us_pbs}=    Evaluate    ${us_cbs}+${us_ebs}
    ${us_pir}=    Evaluate    ${us_eir}+${us_cir}+${us_air}
    # Verify meter for upstream bandwidth profile
    ${us_meter_cmd}=    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${us_cir}, burst-size=${us_cbs}"
    ...     | grep "rate=${us_pir}, burst-size=${us_pbs}" | grep "rate=${us_air}, burst-size=0" | wc -l
    ${upstream_meter_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${us_meter_cmd}
    Should Be Equal As Integers    ${upstream_meter_added}    1     Upstream meter is missing
    Sleep    1s
    # Get downstream bandwidth profile details
    ${ds_cir}    ${ds_cbs}    ${ds_eir}    ${ds_ebs}    ${ds_air}    Get Bandwidth Profile Details
    ...    ${ip}    ${port}    ${ds_bw_profile}
    Sleep    1s
    # Verify meter for downstream bandwidth profile
    ${ds_pbs}=    Evaluate    ${ds_cbs}+${ds_ebs}
    ${ds_pir}=    Evaluate    ${ds_eir}+${ds_cir}+${ds_air}
    ${ds_meter_cmd}=    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${ds_cir}, burst-size=${ds_cbs}"
    ...     | grep "rate=${ds_pir}, burst-size=${ds_pbs}" | grep "rate=${ds_air}, burst-size=0" | wc -l
    ${downstream_meter_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${ds_meter_cmd}
    Should Be Equal As Integers    ${downstream_meter_added}    1   Downstream meter is missing

Verify Default Meter Present in ONOS
    [Arguments]    ${ip}    ${port}    ${olt_of_id}
    [Documentation]    Verifies the single default meter entry is present
    # Get default bandwidth profile details
    ${cir}    ${cbs}    ${eir}    ${ebs}    ${air}    Get Bandwidth Profile Details
    ...    ${ip}    ${port}    'Default'
    Sleep    1s
    ${pbs}=    Evaluate    ${cbs}+${ebs}
    ${pir}=    Evaluate    ${eir}+${cir}+${air}
    # Verify meter for default bandwidth profile
    ${meter_cmd}=    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${cir}, burst-size=${cbs}"
    ...     | grep "rate=${pir}, burst-size=${pbs}" | grep "rate=${air}, burst-size=0" | wc -l
    ${default_meter_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ${meter_cmd}
    # logging all meters to facilitate debug
    ${all_meters}=      Execute ONOS CLI Command use single connection    ${ip}    ${port}      meters
    Log     ${all_meters}
    # done logging all meters to facilitate debug
    Should Be Equal As Integers    ${default_meter_added}    1      Default Meter not present

Verify Device Flows Removed
    [Arguments]    ${ip}    ${port}    ${olt_of_id}
    [Documentation]    Verifies all flows are removed from the device
    ${device_flows}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s -f ${olt_of_id} | grep -v deviceId
    ${flow_count}=      Get Line Count      ${device_flows}
    Should Be Equal As Integers    ${flow_count}    0     Flows not removed

Verify Eapol Flows Added
    [Arguments]    ${ip}    ${port}    ${expected_flows}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_flows}

Verify No Pending Flows For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that there are no flows "PENDING" state for the ONU in ONOS
    ${pending_flows}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    flows -s | grep IN_PORT:${onu_port} | grep PENDING
    Should Be Empty    ${pending_flows}

Verify Eapol Flows Added For ONU
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${c_tag}=4091
    [Documentation]    Verifies if the Eapol Flows are added in ONOS for the ONU
    ${eapol_flow_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep ETH_TYPE:eapol |
    ...    grep VLAN_ID:${c_tag} | grep OUTPUT:CONTROLLER
    ${eapol_flows_added}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}    ${eapol_flow_cmd}
    Should Not Be Empty    ${eapol_flows_added}

Verify UNI Port Is Enabled
    [Arguments]    ${ip}    ${port}    ${onu_name}    ${onu_uni_id}=1
    [Documentation]    Verifies if the ONU's UNI port is enabled in ONOS
    ${onu_port_enabled}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ports -e | grep portName=${onu_name}-${onu_uni_id}
    Log    ${onu_port_enabled}
    Should Not Be Empty    ${onu_port_enabled}

Verify UNI Port Is Disabled
    [Arguments]    ${ip}    ${port}    ${onu_name}    ${onu_uni_id}=1
    [Documentation]    Verifies if the ONU's UNI port is disabled in ONOS
    ${onu_port_disabled}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ports | grep portName=${onu_name}-${onu_uni_id} | grep state=disabled
    Log    ${onu_port_disabled}
    Should Not Be Empty    ${onu_port_disabled}

Wait For All UNI Ports Are Disabled per ONU
    [Documentation]    Verifies all UNI Ports of passed ONU are disabled
    [Arguments]    ${ip}    ${port}    ${onu_serial_number}
    @{uni_id_list}=    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${src['onu']}" != "${onu_serial_number}"
        ${uni_id}=    Set Variable    ${src['uni_id']}
        # make sure all actions do only once per uni_id
        ${id}=    Get Index From List    ${uni_id_list}   ${uni_id}
        Continue For Loop If    -1 != ${id}
        Append To List    ${uni_id_list}    ${uni_id}
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Disabled   ${ip}    ${port}    ${onu_serial_number}    ${uni_id}
    END

Wait For All UNI Ports Are Enabled per ONU
    [Documentation]    Verifies all UNI Ports of passed ONU are enabled
    [Arguments]    ${ip}    ${port}    ${onu_serial_number}
    @{uni_id_list}=    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${src['onu']}" != "${onu_serial_number}"
        ${uni_id}=    Set Variable    ${src['uni_id']}
        # make sure all actions do only once per uni_id
        ${id}=    Get Index From List    ${uni_id_list}   ${uni_id}
        Continue For Loop If    -1 != ${id}
        Append To List    ${uni_id_list}    ${uni_id}
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Enabled   ${ip}    ${port}    ${onu_serial_number}    ${uni_id}
    END

Verify ONU in AAA-Users
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified onu_port exists in aaa-users output
    ${aaa_users}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    aaa-users | grep AUTHORIZED | grep ${onu_port}
    Should Not Be Empty    ${aaa_users}    ONU port ${onu_port} not found in aaa-users

Verify Empty Group in ONOS
    [Documentation]    Verifies zero group count on the device
    [Arguments]    ${ip}    ${port}    ${deviceId}
    ${groups}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}    groups | grep ${deviceId}
    @{groups_arr}=    Split String    ${groups}    ,
    @{group_count_arr}=    Split String    ${groups_arr[1]}    =
    ${group_count}=    Set Variable    ${group_count_arr[1]}
    Should Be Equal As Integers    ${group_count}    0

Verify ONUs in Group Count in ONOS
    [Documentation]    Verifies there exists a group bucket list with certain entries/count
    ...    Note: Currently, this validates only if all ONUs of an OLT joined the same igmp group
    [Arguments]    ${ip}    ${port}    ${count}    ${deviceId}
    ${result}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...   groups added ${deviceId} | grep bucket | wc -l
    Should Be Equal As Integers     ${result}   ${count}    Bucket list count for a group: Found=${result} Expected=${count}

Verify ONU in Group Bucket
    [Documentation]    Matches if ONU port in Group Bucket
    [Arguments]    ${group_bucket_values}    ${onu_port}
    ${len}=    Get Length    ${group_bucket_values}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${len}
        ${value_bucket}=    Get From List    ${group_bucket_values}    ${INDEX}
        ${treatment}=    Get From Dictionary    ${value_bucket}    treatment
        ${instructions}=    Get From Dictionary    ${treatment}    instructions
        ${instructions_val}=    Get From List    ${instructions}    0
        ${port}=    Get From Dictionary    ${instructions_val}    port
        ${matched}=    Set Variable If    '${port}'=='${onu_port}'    True    False
        Exit For Loop If    ${matched}
    END
    [Return]    ${matched}

Verify ONU in Groups
    [Arguments]    ${ip_onos}    ${port_onos}    ${deviceId}    ${onu_port}    ${group_exist}=True
    [Documentation]    Verifies that the specified onu_port exists in groups output
    ${result}=    Execute ONOS CLI Command use single connection    ${ip_onos}    ${port_onos}    groups -j
    Log    Groups: ${result}
    ${groups}=    Convert String To Json    ${result}
    ${length}=    Get Length    ${groups}
    ${buckets}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${groups}    ${INDEX}
        ${devId}=    Get From Dictionary    ${value}    deviceId
        ${bucket}=    Get From Dictionary    ${value}    buckets
        Run Keyword If    '${devId}'=='${deviceId}'
        ...    Append To List    ${buckets}    ${bucket}
    END
    ${bucket_len}=    Get Length    ${buckets}
    FOR    ${INDEX_1}    IN RANGE    0    ${bucket_len}
        ${value}=    Get From List    ${buckets}    ${INDEX_1}
        ${matched}=    Verify ONU in Group Bucket    ${value}    ${onu_port}
        Exit For Loop If    ${matched}
    END
    Run Keyword If    ${group_exist}
    ...    Should Be True    ${matched}    No match for ${deviceId} and ${onu_port} found in ONOS groups
    ...    ELSE
    ...    Should Be True    '${matched}'=='False'    Match for ${deviceId} and ${onu_port} found in ONOS groups

Assert Number of AAA-Users
    [Arguments]    ${ip}    ${port}    ${expected_onus}   ${deviceId}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ${aaa_users}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...     aaa-users | grep ${deviceId} | grep AUTHORIZED | wc -l
    Log     Found ${aaa_users} of ${expected_onus} expected authenticated users on device ${deviceId}
    Should Be Equal As Integers    ${aaa_users}    ${expected_onus}

Validate DHCP Allocations
    [Arguments]    ${ip}    ${port}    ${count}   ${workflow}     ${deviceId}
    [Documentation]    Matches for number of dhcpacks based on number of onus
    ${allocations}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...     dhcpl2relay-allocations | grep ${deviceId} | grep DHCPACK | wc -l
    # if the workflow is TT we'll have 2 allocations for each ONU
    ${ttAllocations}=     Evaluate   (${count} * 2)
    ${count}=    Set Variable If  $workflow=='tt'    ${ttAllocations}   ${count}
    Log     Found ${allocations} of ${count} expected DHCPACK on device ${deviceId}
    Should Be Equal As Integers    ${allocations}    ${count}

Validate Subscriber DHCP Allocation
    [Arguments]    ${ip}    ${port}    ${onu_port}   ${vlan}=''
    [Documentation]    Verifies that the specified subscriber is found in DHCP allocations
    ##TODO: Enhance the keyword to include DHCP allocated address is not 0.0.0.0
    ${allocations}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    dhcpl2relay-allocations | grep DHCPACK | grep ${onu_port} | grep ${vlan}
    Should Not Be Empty    ${allocations}    ONU port ${onu_port} not found in dhcpl2relay-allocations

Validate Mac Learner Mapping in ONOS
    [Arguments]    ${ip}    ${port}    ${dev_id}    ${onu_port}    ${vlan}
    [Documentation]    Verifies the MAC mapping for the client
    ${mac}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    mac-learner-get-mapping ${dev_id} ${onu_port} ${vlan} | grep -v INFO
    Should Not Be Empty    ${mac}
    ...    No client mac-mapping found with vlan-id: ${vlan} that uses port: ${onu_port} of device: ${dev_id}

Device Is Available In ONOS
    [Arguments]    ${url}    ${dpid}    ${available}=true
    [Documentation]    Validates the device exists and it has the expected availability in ONOS
    ${rc}    ${json}    Run And Return Rc And Output    curl --fail -sSL ${url}/onos/v1/devices/${dpid}
    Should Be Equal As Integers    0    ${rc}
    ${rc}    ${value}    Run And Return Rc And Output    echo '${json}' | jq -r .available
    Should Be Equal As Integers    0    ${rc}
    Should Be Equal    ${available}    ${value}

Remove All Devices From ONOS
    [Arguments]    ${url}
    [Documentation]    Executes the device-remove command on each device in ONOS
    ${rc}    ${output}    Run And Return Rc And Output
    ...    curl --fail -sSL ${url}/onos/v1/devices | jq -r '.devices[].id'
    Should Be Equal As Integers    ${rc}    0
    @{dpids}    Split String    ${output}
    ${count}=    Get length    ${dpids}
    FOR    ${dpid}    IN    @{dpids}
        ${rc}=    Run Keyword If    '${dpid}' != ''
        ...    Run And Return Rc    curl -XDELETE --fail -sSL ${url}/onos/v1/devices/${dpid}
        Run Keyword If    '${dpid}' != ''
        ...    Should Be Equal As Integers    ${rc}    0
    END

Assert ONU Port Is Disabled
    [Arguments]    ${ip}    ${port}    ${deviceId}    ${onu_port}
    [Documentation]    Verifies if the ONU port is disabled in ONOS
    ${onu_port_disabled}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ports -d ${deviceId} | grep port=${onu_port}
    Log    ${onu_port_disabled}
    Should Not Be Empty    ${onu_port_disabled}

Assert Olts in ONOS
    [Arguments]    ${ip}    ${port}     ${count}
    [Documentation]    DEPRECATED use Assert Olt in ONOS
    ...     Check that a certain number of olts are known to ONOS
    ${olts}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    volt-olts | wc -l
    Log     Found ${olts} of ${count} expected Olts
    Should Be Equal As Integers    ${olts}    ${count}

Assert Olt in ONOS
    [Arguments]    ${ip}    ${port}     ${deviceId}
    [Documentation]    Check that a particular olt is known to ONOS
    ${olts}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    volt-olts | grep ${deviceId} | wc -l
    Should Be Equal As Integers    ${olts}    1   "Device ${deviceId} is not recognized as an OLT"

Wait for Olts in ONOS
    [Arguments]    ${ip}    ${port}    ${count}   ${max_wait_time}=10m
    [Documentation]    DEPRECATED use Wait for Olt in ONOS
    ...     Waits untill a certain number of ports are enabled in ONOS for a particular deviceId
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Olts in ONOS
    ...     ${ip}    ${port}     ${count}

Wait for Olt in ONOS
    [Arguments]    ${ip}    ${port}    ${deviceId}   ${max_wait_time}=10m
    [Documentation]    Waits until a particular deviceId is recognized by ONOS as an OLT
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Olt in ONOS
    ...     ${ip}    ${port}     ${deviceId}

Assert Ports in ONOS
    [Arguments]    ${ip}    ${port}     ${count}     ${deviceId}    ${filter}
    [Documentation]    Check that a certain number of ports are enabled in ONOS
    ...                Attention: With use of Rest APi filter is used only for 'portName'!
    ${ports}=    Execute ONOS Rest API Request use single session     ${ONOS_REST_IP}    ${ONOS_REST_PORT}
    ...  GET    onos/v1/devices/${deviceId}/ports
    Run Keyword If    "${ports}"!="${EMPTY}"    Log   ${ports}
    ${nb_ports}=    Run Keyword If    "${ports}"!="${EMPTY}"    Get Length    ${ports['ports']}
    ...                       ELSE    Set Variable    0
    ${found_ports}=    Set Variable    0
    FOR    ${I}    IN RANGE    0    ${nb_ports}
        Log    ${ports['ports'][${I}]}
        ${filter_found}=   Run Keyword And Return Status   Should Contain   ${ports['ports'][${I}]['annotations']['portName']}
        ...    ${filter}
        ${Enabled}=    Set Variable    ${ports['ports'][${I}]['isEnabled']}
        ${found_ports}=    Run Keyword If   ${filter_found} and ${Enabled}    evaluate    ${found_ports} + 1
        ...                          ELSE   Set Variable    ${found_ports}
    END
    Log     Found ${found_ports} of ${count} expected ports on device ${deviceId}
    Should Be Equal As Integers    ${found_ports}    ${count}
# old code with ONOS CLI:
#    ${ports}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
#        ...    ports -e ${deviceId} | grep ${filter} | wc -l
#    Log     Found ${ports} of ${count} expected ports on device ${deviceId}
#    Should Be Equal As Integers    ${ports}    ${count}

Wait for Ports in ONOS
    [Arguments]    ${ip}    ${port}    ${count}    ${deviceId}    ${filter}    ${max_wait_time}=10m
    [Documentation]    Waits untill a certain number of ports are enabled in ONOS for a particular deviceId
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Ports in ONOS
    ...     ${ip}    ${port}     ${count}     ${deviceId}     ${filter}

Wait for AAA Authentication
    [Arguments]    ${ip}    ${port}    ${count}    ${deviceId}    ${max_wait_time}=10m
    [Documentation]    Waits untill a certain number of subscribers are authenticated in ONOS
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Number of AAA-Users
    ...     ${ip}    ${port}     ${count}     ${deviceId}

Wait for DHCP Ack
    [Arguments]    ${ip}    ${port}    ${count}    ${workflow}    ${deviceId}    ${max_wait_time}=10m
    [Documentation]    Waits untill a certain number of subscribers have received a DHCP_ACK
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Validate DHCP Allocations
        ...     ${ip}    ${port}     ${count}    ${workflow}    ${deviceId}

Provision subscriber REST
    [Documentation]     Uses the rest APIs to provision a subscriber
    [Arguments]     ${of_id}    ${onu_port}
    ${resp}=    Post Request    ONOS
    ...    /onos/olt/oltapp/${of_id}/${onu_port}
    Should Be Equal As Strings    ${resp.status_code}    200

Count Enabled UNI Ports
    [Documentation]    Count all the UNI Ports on a Device
    [Arguments]     ${ip}    ${port}   ${of_id}
    ${count}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ports -e ${of_id} | grep -v SWITCH | grep -v nni | wc -l
    Log    ${count}
    [Return]    ${count}

List Enabled UNI Ports
    [Documentation]  List all the UNI Ports, the only way we have is to filter out the one called NNI
    ...     Creates a list of dictionaries
    [Arguments]     ${ip}    ${port}   ${of_id}
    [Return]  [{'port': '16', 'of_id': 'of:00000a0a0a0a0a00'}, {'port': '32', 'of_id': 'of:00000a0a0a0a0a00'}]
    ${result}=      Create List
    ${out}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...    ports -e ${of_id} | grep -v SWITCH | grep -v nni
    @{unis}=    Split To Lines    ${out}
    FOR    ${uni}    IN    @{unis}
        ${matches} =    Get Regexp Matches    ${uni}  .*port=([0-9]+),.*  1
        &{portDict}    Create Dictionary    of_id=${of_id}    port=${matches[0]}
        Append To List  ${result}    ${portDict}
    END
    Log     ${result}
    Return From Keyword     ${result}

Provision all subscribers on device
    [Documentation]  Provisions a subscriber in ONOS for all the enabled UNI ports on a particular device
    [Arguments]     ${ip}    ${port}  ${onos_ip}  ${onos_rest_port}   ${of_id}
    ${unis}=    List Enabled UNI Ports  ${ip}    ${port}   ${of_id}
    ${onos_auth}=    Create List    karaf    karaf
    Create Session    ONOS    http://${onos_ip}:${onos_rest_port}    auth=${onos_auth}
    FOR     ${uni}  IN      @{unis}
        Provision Subscriber REST   ${uni['of_id']}   ${uni['port']}
    END

List OLTs
    # NOTE this method is not currently used but it can come useful in the future
    [Documentation]  Returns a list of all OLTs known to ONOS
    [Arguments]  ${ip}    ${port}
    [Return]  ['of:00000a0a0a0a0a00', 'of:00000a0a0a0a0a01']
    ${result}=      Create List
    ${out}=    Execute ONOS CLI Command use single connection    ${ip}    ${port}
    ...     volt-olts
    @{olts}=    Split To Lines    ${out}
    FOR    ${olt}    IN    @{olts}
        Log     ${olt}
        ${matches} =    Get Regexp Matches    ${olt}  ^OLT (.+)$  1
        # there may be some logs mixed with the output so only append if we have a match
        ${matches_length}=      Get Length  ${matches}
        Run Keyword If  ${matches_length}==1
        ...     Append To List  ${result}    ${matches[0]}
    END
    Return From Keyword     ${result}

Count flows
    [Documentation]     Count flows in a particular ${state} in ONOS
    ...                 Optionally for a certain onu-port.
    [Arguments]  ${ip}    ${port}    ${deviceId}   ${state}    ${onu_port}=${EMPTY}
    ${cmd}=    Catenate    SEPARATOR=    flows -s ${state} ${deviceId} | grep -v deviceId
    ${cmd}=    Run Keyword If    "${onu_port}"!="${EMPTY}"    Catenate    SEPARATOR=    ${cmd} | grep ${onu_port}
    ...        ELSE    Set Variable    ${cmd}
    ${cmd}=    Catenate    SEPARATOR=    ${cmd} | wc -l
    ${flows}=  Execute ONOS CLI Command use single connection    ${ip}    ${port}    ${cmd}
    [return]   ${flows}

Validate number of flows
    [Documentation]     Validates number of flows in a particular ${state} in ONOS
    ...                 Optionally for a certain onu-port.
    [Arguments]  ${ip}    ${port}    ${targetFlows}   ${deviceId}   ${state}    ${onu_port}=${EMPTY}
    ${flows}=    Count flows    ${ip}    ${port}    ${deviceId}   ${state}    ${onu_port}
    Log     Found ${state} ${flows} of ${targetFlows} expected flows on device ${deviceId}
    Should Be Equal As Integers    ${targetFlows}    ${flows}

Wait for all flows to in ADDED state
    [Documentation]  Waits until the flows have been provisioned
    [Arguments]  ${ip}    ${port}     ${deviceId}     ${workflow}    ${uni_count}    ${olt_count}
    ...    ${provisioned}     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    ${targetFlows}=     Calculate flows by workflow     ${workflow}    ${uni_count}    ${olt_count}     ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    Wait Until Keyword Succeeds     10m     5s      Validate number of flows
    ...     ${ip}    ${port}  ${targetFlows}  ${deviceId}   added

Wait for all flows to be removed
    [Documentation]     Wait for all flows to be removed from a particular device
    [Arguments]     ${ip}   ${port}     ${deviceId}
    Wait Until Keyword Succeeds     10m     5s      Validate number of flows
    ...     ${ip}    ${port}  0  ${deviceId}   any

Check All Flows Removed
    [Documentation]    Checks all flows removed per OLT
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        ${onu_port_list}=    Get ONU Ports per OLT    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
        Check All Flows Removed per OLT    ${of_id}    ${onu_port_list}
    END

Check All Flows Removed per OLT
    [Documentation]    Checks all flows removed per OLT, in case of flow remove, not after delete device!
    ...                Attention: For ATT there must be the eapol flow still available!
    [Arguments]        ${of_id}    ${onu_port_list}
    ${expected_flows_onu}=    Set Variable If   "${workflow}"=="ATT"    1    0
    FOR  ${onu_port}  IN  @{onu_port_list}
        Wait Until Keyword Succeeds    ${timeout}    2s    Validate number of flows    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    ${expected_flows_onu}  ${of_id}   any    ${onu_port}
    END

Get ONU Ports per OLT
    [Documentation]    Collects all ONU ports per OLT
    [Arguments]        ${olt}
    ${onu_port_list}    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt}"!="${src['olt']}"
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${port_id}=    Get Index From List    ${onu_port_list}   ${onu_port}
        Continue For Loop If    -1 != ${port_id}
        Append To List    ${onu_port_list}    ${onu_port}
    END
    [return]    ${onu_port_list}

Get Limiting Bandwidth Details
    [Arguments]    ${bandwidth_profile_name}
    [Documentation]    Collects the bandwidth profile details for the given bandwidth profile and
    ...    returns the limiting bandwidth
    ${cir}    ${cbs}    ${eir}    ${ebs}    ${air}=    Get Bandwidth Profile Details Rest
    ...    ${bandwidth_profile_name}
    ${limiting_BW}=    Evaluate    ${eir}+${cir}+${air}
    [Return]    ${limiting_BW}

Get Limiting Bandwidth Details for Fixed and Committed
    [Arguments]    ${bandwidth_profile_name}
    [Documentation]    Collects the bandwidth profile details for the given bandwidth profile and
    ...    returns the limiting bandwidth for fixed and committed
    ${cir}    ${cbs}    ${eir}    ${ebs}    ${air}=    Get Bandwidth Profile Details Rest
    ...    ${bandwidth_profile_name}
    ${limiting_BW}=    Evaluate    ${cir}+${air}
    [Return]    ${limiting_BW}

Validate Deleted Device Cleanup In ONOS
    [Arguments]    ${ip}    ${port}    ${olt_serial_number}    ${maclearning_enabled}=False
    [Documentation]    The keyword verifies that ports, flows, meters, subscribers, dhcp are all cleared in ONOS
    # Fetch OF Id for OLT
    ${olt_of_id}=    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device in ONOS    ${olt_serial_number}
    # Verify Ports are Removed
    ${ports}=    Execute ONOS Rest API Request use single session     ${ONOS_REST_IP}    ${ONOS_REST_PORT}
    ...  GET    onos/v1/devices/${olt_of_id}/ports
    Log   ${ports}
    Should Be Empty    ${ports['ports']}    Ports have not been removed from ONOS after cleanup
    # Verify Subscribers are Removed
    ${sub}=    Execute ONOS CLI Command use single connection     ${ip}    ${port}
    ...    volt-programmed-subscribers | grep ${olt_of_id}
    ${sub_count}=      Get Line Count      ${sub}
    Should Be Equal As Integers    ${sub_count}    0    Subscribers have not been removed from ONOS after cleanup
    # Verify Flows are Removed
    ${flow}=    Execute ONOS Rest API Request use single session     ${ONOS_REST_IP}    ${ONOS_REST_PORT}
    ...    GET    onos/v1/flows/${olt_of_id}
    Log   ${flow}
    Should Not Contain      ${flow}    ${olt_of_id}    Flows have not been removed from ONOS after cleanup
    # Verify Meters are Removed
    ${meter}=    Execute ONOS Rest API Request use single session     ${ONOS_REST_IP}    ${ONOS_REST_PORT}
    ...    GET    onos/v1/meters/${olt_of_id}
	Log    ${meter}
    Should Be Empty    ${meter['meters']}    Meters have not been removed from ONOS after cleanup
    # Verify AAA-Users are Removed
    ${aaa}=    Execute ONOS CLI Command use single connection     ${ip}    ${port}
    ...    aaa-users ${olt_of_id}
    ${aaa_count}=      Get Line Count      ${aaa}
    Should Be Equal As Integers    ${aaa_count}    0    AAA Users have not been removed from ONOS after cleanup
    # Verify Dhcp-Allocations are Removed
    ${dhcp}=    Execute ONOS CLI Command use single connection     ${ip}    ${port}
    ...    dhcpl2relay-allocations ${olt_of_id}
    ${dhcp_count}=      Get Line Count      ${dhcp}
    Should Be Equal As Integers    ${dhcp_count}    0   DHCP Allocations have not been removed from ONOS after cleanup
    # Verify MAC Learner Mappings are Removed
    ${mac}=    Run Keyword If    ${maclearning_enabled}    Execute ONOS Rest API Request use single session     ${ONOS_REST_IP}
    ...    ${ONOS_REST_IP}    ${ONOS_REST_PORT}    GET    /onos/v2/maclearner/mapping/all
    ${mac_count}=    Run Keyword If    ${maclearning_enabled}    Get Length    ${mac['data']}
    ...    ELSE    Set Variable    0
    Should Be Equal As Integers    ${mac_count}    0   Client MAC Learner Mappings have not been removed from ONOS after cleanup

Delete ONOS App
    [Arguments]    ${url}    ${app_name}
    [Documentation]    This keyword deactivates and uninstalls the given ONOS App
    ${rc}=    Run And Return Rc    curl --fail -sSL -X DELETE ${url}/onos/v1/applications/${app_name}
    Should Be Equal As Integers    ${rc}    0   Can't delete ${app_name} from ONOS

Verify ONOS App Active
    [Arguments]    ${url}    ${app_name}    ${app_version}=${EMPTY}
    [Documentation]    This keyword verifies that the given ONOS App status is Active
    ${rc}    ${output}    Run And Return Rc And Output
    ...    curl --fail -sSL ${url}/onos/v1/applications/${app_name} | jq -r .state
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal    '${output}'    'ACTIVE'
    ${rc1}    ${output1}    Run And Return Rc And Output
    ...    curl --fail -sSL ${url}/onos/v1/applications/${app_name} | jq -r .version
    Run Keyword If    '${app_version}'!='${EMPTY}'
    ...    Run Keywords
    ...    Should Be Equal As Integers    ${rc1}    0   Can't read app ${app_name} status from ONOS
    ...    AND    Should Be Equal    '${output1}'    '${app_version}'

Install And Activate ONOS App
    [Arguments]    ${url}    ${app_oar_file}
    [Documentation]    This keyword installs and activates the given ONOS App
    ${cmd}=    Catenate    SEPARATOR=
    ...    curl --fail -sSL -H Content-Type:application/octet-stream -
    ...    X POST ${url}/onos/v1/applications?activate=true --data-binary \@${app_oar_file}
    ${rc}    ${output}    Run And Return Rc And Output    ${cmd}
    Should Be Equal As Integers    ${rc}    0   Can't load onos app ${app_oar_file} to ONOS"
    Log    ${output}

Get ONOS App Details
    [Arguments]    ${url}    ${app_name}
    [Documentation]    Retrieves ONOS App Details
    ${rc}    ${output}    Run And Return Rc And Output
    ...    curl --fail -sSL ${url}/onos/v1/applications/${app_name}
    Should Be Equal As Integers    ${rc}    0   Can't read app ${app_name} details from ONOS
    [Return]    ${output}

Verify UniTag Subscriber
    [Documentation]    Verifies the unitag subscriber is provisioned/un-provisioned
    [Arguments]    ${ip}    ${port}    ${dev_id}    ${onu_port}    ${stag}    ${ctag}    ${tpid}    ${sub_added}=True
    ${cmd}=    Catenate    SEPARATOR=
    ...    volt-programmed-subscribers ${dev_id} ${onu_port} | grep "ponCTag=${ctag}, ponSTag=${stag}" | grep technologyProfileId
    ...    =${tpid} --color=none
    ${subscriber}=    Execute ONOS CLI Command use single connection     ${ip}    ${port}    ${cmd}
    Log    ${subscriber}
    ${sub_count}=    Get Line Count    ${subscriber}
    Run Keyword If    ${sub_added}
    ...    Should Be Equal As Integers    ${sub_count}    1    UniTag Subscriber Not Added
    ...    ELSE
    ...    Should Be Equal As Integers    ${sub_count}    0    UniTag Subscriber Not Removed
