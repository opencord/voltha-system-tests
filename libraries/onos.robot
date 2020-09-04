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

*** Keywords ***

Open ONOS SSH Connection
    [Documentation]    Establishes an ssh connection to ONOS contoller
    [Arguments]    ${host}    ${port}    ${user}=karaf    ${pass}=karaf
    ${conn_id}=    SSHLibrary.Open Connection    ${host}    port=${port}    timeout=300s    alias=ONOS_SSH
    SSHLibrary.Login    ${user}    ${pass}
    ${conn_list_entry}=    Create Dictionary    conn_id=${conn_id}    user=${user}    pass=${pass}
    Append To List    ${connection_list}    ${conn_list_entry}
    ${conn_list_id}=    Get Index From List    ${connection_list}    ${conn_list_entry}
    Set Global Variable    ${connection_list}
    [Return]    ${conn_list_id}

Execute ONOS CLI Command on open connection
    [Documentation]    Execute ONOS CLI Command On an Open Connection
    [Arguments]    ${connection_list_id}  ${cmd}
    ${connection_entry}=    Get From List   ${connection_list}    ${connection_list_id}
    SSHLibrary.Switch Connection   ${connection_entry.conn_id}
    ${PassOrFail}    @{result_values}    Run Keyword And Ignore Error    SSHLibrary.Execute Command    ${cmd}
    ...    return_rc=True    return_stderr=True    return_stdout=True
    Run Keyword If    '${PassOrFail}'=='FAIL'    Reconnect ONOS SSH Connection    ${connection_list_id}
    @{result_values}=    Run Keyword If    '${PassOrFail}'=='FAIL'
    ...    SSHLibrary.Execute Command    ${cmd}    return_rc=True    return_stderr=True    return_stdout=True
    ...    ELSE    Set Variable    @{result_values}
    ${output}    Set Variable    @{result_values}[0]
    Log    Command output: ${output}
    Should Be Empty    @{result_values}[1]
    Should Be Equal As Integers    @{result_values}[2]    0
    [Return]    ${output}

Reconnect ONOS SSH Connection
    [Documentation]    Reconnect an SSH Connection
    [Arguments]    ${connection_list_id}
    ${connection_entry}=    Get From List   ${connection_list}    ${connection_list_id}
    ${user}=    Get From Dictionary    ${connection_entry}    user
    ${pass}=    Get From Dictionary    ${connection_entry}    pass
    ${oldconndata}=    Get Connection    ${connection_entry.conn_id}
    SSHLibrary.Switch Connection   ${connection_entry.conn_id}
    Run Keyword And Ignore Error    SSHLibrary.Close Connection
    ${conn_id}=    SSHLibrary.Open Connection    ${oldconndata.host}    port=${oldconndata.port}
    ...    timeout=300s    alias=ONOS_SSH
    SSHLibrary.Login    ${user}    ${pass}
    ${conn_list_entry}=    Create Dictionary    conn_id=${conn_id}    user=${user}    pass=${pass}
    Set List Value    ${connection_list}    ${connection_list_id}    ${conn_list_entry}
    Set Global Variable    ${connection_list}

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

Validate OLT Device in ONOS
    #    FIXME use volt-olts to check that the OLT is ONOS
    [Arguments]    ${serial_number}
    [Documentation]    Checks if olt has been connected to ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
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
    [Arguments]    ${onu_serial_number}    ${olt_of_id}
    [Documentation]    Retrieves ONU port for the ONU in ONOS
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_serial_number}    1
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}
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

Get NNI Port in ONOS
    [Arguments]    ${olt_of_id}
    [Documentation]    Retrieves NNI port for the OLT in ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
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
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
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
    ${resp}=    Get Request    ONOS    onos/v1/mastership/${of_id}/master
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['nodeId']}
    ${master_node}=    Get From Dictionary    ${jsondata}    nodeId
    [Return]    ${master_node}

Verify Subscriber Access Flows Added for ONU
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${c_tag}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:0 |
    ...     grep VLAN_ID:${c_tag} | grep transition=TABLE:1
    ${upstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${upstream_flow_0_cmd}
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_ID:0 | grep OUTPUT:${onu_port}
    ${downstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${downstream_flow_1_cmd}
    Should Not Be Empty    ${downstream_flow_1_added}
    # Verify ipv4 dhcp upstream flow
    ${upstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep ETH_TYPE:ipv4 |
    ...     grep IP_PROTO:17 | grep UDP_SRC:68 | grep UDP_DST:67 | grep VLAN_ID:${c_tag} |
    ...     grep OUTPUT:CONTROLLER
    ${upstream_flow_ipv4_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${upstream_flow_ipv4_cmd}
    Should Not Be Empty    ${upstream_flow_ipv4_added}
    # Verify ipv4 dhcp downstream flow
    # Note: This flow will be one per nni per olt
    ${downstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep ETH_TYPE:ipv4 |
    ...     grep IP_PROTO:17 | grep UDP_SRC:67 | grep UDP_DST:68 | grep OUTPUT:CONTROLLER
    ${downstream_flow_ipv4_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${downstream_flow_ipv4_cmd}
    Should Not Be Empty    ${downstream_flow_ipv4_added}

Verify Subscriber Access Flows Added for ONU DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any | grep transition=TABLE:1
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:Any | grep OUTPUT:${onu_port}
    Should Not Be Empty    ${downstream_flow_1_added}

Verify Subscriber Access Flows Added Count DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${expected_flows}
    [Documentation]    Matches for total number of subscriber access flows added for all onus
    ${access_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep -v deviceId | grep -v ETH_TYPE:lldp | wc -l
    Should Be Equal As Integers    ${access_flows_added}    ${expected_flows}

Get Programmed Subscribers
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}
    [Documentation]    Retrieves the subscriber details at a given location
    ${sub_location}=    Catenate    SEPARATOR=/    ${olt_of_id}    ${onu_port}
    ${programmed_sub}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    volt-programmed-subscribers | grep ${sub_location}
    [Return]    ${programmed_sub}

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
    ${bw_profile_values}=    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
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

Verify Meters in ONOS
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}
    [Documentation]    Verifies the meters
    # Get programmed subscriber
    ${programmed_sub}=    Get Programmed Subscribers    ${ip}    ${port}
    ...    ${olt_of_id}    ${onu_port}
    Log    ${programmed_sub}
    ${us_bw_profile}    ${ds_bw_profile}    Get Upstream and Downstream Bandwidth Profile Name
    ...    ${programmed_sub}
    # Get upstream bandwidth profile details
    ${us_cir}    ${us_cbs}    ${us_eir}    ${us_ebs}    ${us_air}    Get Bandwidth Profile Details
    ...    ${ip}    ${port}    ${us_bw_profile}
    Sleep    1s
    # Verify meter for upstream bandwidth profile
    ${us_meter_cmd}=    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${us_cir}, burst-size=${us_cbs}"
    ...     | grep "rate=${us_eir}, burst-size=${us_ebs}" | grep "rate=${us_air}, burst-size=0" | wc -l
    ${upstream_meter_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${us_meter_cmd}
    Should Be Equal As Integers    ${upstream_meter_added}    1
    Sleep    1s
    # Get downstream bandwidth profile details
    ${ds_cir}    ${ds_cbs}    ${ds_eir}    ${ds_ebs}    ${ds_air}    Get Bandwidth Profile Details
    ...    ${ip}    ${port}    ${ds_bw_profile}
    Sleep    1s
    # Verify meter for downstream bandwidth profile
    ${ds_meter_cmd}=    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${ds_cir}, burst-size=${ds_cbs}"
    ...     | grep "rate=${ds_eir}, burst-size=${ds_ebs}" | grep "rate=${ds_air}, burst-size=0" | wc -l
    ${downstream_meter_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${ds_meter_cmd}
    Should Be Equal As Integers    ${downstream_meter_added}    1

Verify Default Meter Present in ONOS
    [Arguments]    ${ip}    ${port}    ${olt_of_id}
    [Documentation]    Verifies the single default meter entry is present
    # Get default bandwidth profile details
    ${cir}    ${cbs}    ${eir}    ${ebs}    ${air}    Get Bandwidth Profile Details
    ...    ${ip}    ${port}    'Default'
    Sleep    1s
    # Verify meter for default bandwidth profile
    ${meter_cmd}=    Catenate    SEPARATOR=
    ...    meters ${olt_of_id} | grep state=ADDED | grep "rate=${cir}, burst-size=${cbs}"
    ...     | grep "rate=${eir}, burst-size=${ebs}" | grep "rate=${air}, burst-size=0" | wc -l
    ${default_meter_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${meter_cmd}
    Should Be Equal As Integers    ${default_meter_added}    1

Verify Device Flows Removed
    [Arguments]    ${ip}    ${port}    ${olt_of_id}
    [Documentation]    Verifies all flows are removed from the device
    ${device_flows}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ${olt_of_id} | grep -v deviceId | wc -l
    Should Be Equal As Integers    ${device_flows}    0

Verify Eapol Flows Added
    [Arguments]    ${ip}    ${port}    ${expected_flows}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_flows}

Verify No Pending Flows For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that there are no flows "PENDING" state for the ONU in ONOS
    ${pending_flows}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s | grep IN_PORT:${onu_port} | grep PENDING
    Should Be Empty    ${pending_flows}

Verify Eapol Flows Added For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the Eapol Flows are added in ONOS for the ONU
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT:${onu_port}
    Should Not Be Empty    ${eapol_flows_added}

Verify ONU Port Is Enabled
    [Arguments]    ${ip}    ${port}    ${onu_name}
    [Documentation]    Verifies if the ONU port is enabled in ONOS
    ${onu_port_enabled}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ports -e | grep portName=${onu_name}
    Log    ${onu_port_enabled}
    Should Not Be Empty    ${onu_port_enabled}

Verify ONU Port Is Disabled
    [Arguments]    ${ip}    ${port}    ${onu_name}
    [Documentation]    Verifies if the ONU port is disabled in ONOS
    ${onu_port_disabled}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ports -e | grep portName=${onu_name}
    Log    ${onu_port_disabled}
    Should Be Empty    ${onu_port_disabled}

Verify ONU in AAA-Users
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified onu_port exists in aaa-users output
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | grep ${onu_port}
    Should Not Be Empty    ${aaa_users}    ONU port ${onu_port} not found in aaa-users

Verify ONU in Groups
    [Arguments]    ${ip_onos}    ${port_onos}    ${deviceId}    ${onu_port}    ${group_exist}=True
    [Documentation]    Verifies that the specified onu_port exists in groups output
    ${result}=    Execute ONOS CLI Command    ${ip_onos}    ${port_onos}    groups -j
    Log    Groups: ${result}
    ${groups}=    To Json    ${result}
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
    FOR    ${INDEX1}    IN RANGE    0    ${bucket_len}
        ${value}=    Get From List    ${buckets}    ${INDEX}
        ${value_bucket}=    Get From List    ${value}    0
        ${treatment}=    Get From Dictionary    ${value_bucket}    treatment
        ${instructions}=    Get From Dictionary    ${treatment}    instructions
        ${instructions_val}=    Get From List    ${instructions}    0
        ${port}=    Get From Dictionary    ${instructions_val}    port
        ${matched}=    Set Variable If    '${port}'=='${onu_port}'    True    False
        Exit For Loop If    ${matched}
    END
    Run Keyword If    ${group_exist}
    ...    Should Be True    ${matched}    No match for ${deviceId} and ${onu_port} found in ONOS groups
    ...    ELSE
    ...    Should Be True    '${matched}'=='False'    Match for ${deviceId} and ${onu_port} found in ONOS groups

Assert Number of AAA-Users
    [Arguments]    ${onos_ssh_connection}    ${expected_onus}   ${deviceId}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ${aaa_users}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...     aaa-users | grep ${deviceId} | grep AUTHORIZED | wc -l
    Log     Found ${aaa_users} of ${expected_onus} expected authenticated users on device ${deviceId}
    Should Be Equal As Integers    ${aaa_users}    ${expected_onus}

Validate DHCP Allocations
    [Arguments]    ${onos_ssh_connection}    ${count}   ${workflow}     ${deviceId}
    [Documentation]    Matches for number of dhcpacks based on number of onus
    ${allocations}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
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
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    dhcpl2relay-allocations | grep DHCPACK | grep ${onu_port} | grep ${vlan}
    Should Not Be Empty    ${allocations}    ONU port ${onu_port} not found in dhcpl2relay-allocations

Device Is Available In ONOS
    [Arguments]    ${url}    ${dpid}
    [Documentation]    Validates the device exists and it available in ONOS
    ${rc}    ${json}    Run And Return Rc And Output    curl --fail -sSL ${url}/onos/v1/devices/${dpid}
    Should Be Equal As Integers    0    ${rc}
    ${rc}    ${value}    Run And Return Rc And Output    echo '${json}' | jq -r .available
    Should Be Equal As Integers    0    ${rc}
    Should Be Equal    'true'    '${value}'

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
    [Arguments]    ${onos_ssh_connection}    ${deviceId}    ${onu_port}
    [Documentation]    Verifies if the ONU port is disabled in ONOS
    ${onu_port_disabled}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    ports -d ${deviceId} | grep port=${onu_port}
    Log    ${onu_port_disabled}
    Should Not Be Empty    ${onu_port_disabled}

Assert Ports in ONOS
    [Arguments]    ${onos_ssh_connection}     ${count}     ${deviceId}    ${filter}
    [Documentation]    Check that a certain number of ports are enabled in ONOS
    ${ports}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
        ...    ports -e ${deviceId} | grep ${filter} | wc -l
    Log     Found ${ports} of ${count} expected ports on device ${deviceId}
    Should Be Equal As Integers    ${ports}    ${count}

Wait for Ports in ONOS
    [Arguments]    ${onos_ssh_connection}    ${count}    ${deviceId}    ${filter}    ${max_wait_time}=10m
    [Documentation]    Waits untill a certain number of ports are enabled in ONOS for a particular deviceId
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Ports in ONOS
    ...     ${onos_ssh_connection}     ${count}     ${deviceId}     ${filter}

Wait for AAA Authentication
    [Arguments]    ${onos_ssh_connection}    ${count}    ${deviceId}    ${max_wait_time}=10m
    [Documentation]    Waits untill a certain number of subscribers are authenticated in ONOS
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Assert Number of AAA-Users
    ...     ${onos_ssh_connection}     ${count}     ${deviceId}

Wait for DHCP Ack
    [Arguments]    ${onos_ssh_connection}    ${count}    ${workflow}    ${deviceId}    ${max_wait_time}=10m
    [Documentation]    Waits untill a certain number of subscribers have received a DHCP_ACK
    Wait Until Keyword Succeeds     ${max_wait_time}     5s      Validate DHCP Allocations
        ...     ${onos_ssh_connection}     ${count}    ${workflow}    ${deviceId}

Provision subscriber
    [Documentation]  Calls volt-add-subscriber-access in ONOS
    [Arguments]    ${onos_ip}    ${onos_port}   ${of_id}    ${onu_port}
    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
            ...    volt-add-subscriber-access ${of_id} ${onu_port}

Provision subscriber REST
    [Documentation]     Uses the rest APIs to provision a subscriber
    [Arguments]     ${onos_ip}    ${onos_port}   ${of_id}    ${onu_port}
    ${resp}=    Post Request    ONOS
    ...    /onos/olt/oltapp/${of_id}/${onu_port}
    Should Be Equal As Strings    ${resp.status_code}    200


List Enabled UNI Ports
    [Documentation]  List all the UNI Ports, the only way we have is to filter out the one called NNI
    ...     Creates a list of dictionaries
    [Arguments]     ${onos_ssh_connection}   ${of_id}
    [Return]  [{'port': '16', 'of_id': 'of:00000a0a0a0a0a00'}, {'port': '32', 'of_id': 'of:00000a0a0a0a0a00'}]
    ${result}=      Create List
    ${out}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
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
    [Arguments]     ${onos_ssh_connection}  ${onos_ip}  ${onos_rest_port}   ${of_id}
    ${unis}=    List Enabled UNI Ports  ${onos_ssh_connection}   ${of_id}
    ${onos_auth}=    Create List    karaf    karaf
    Create Session    ONOS    http://${onos_ip}:${onos_rest_port}    auth=${onos_auth}
    FOR     ${uni}  IN      @{unis}
        Provision Subscriber REST   ${onos_ip}  ${onos_rest_port}   ${uni['of_id']}   ${uni['port']}
    END

List OLTs
    # NOTE this method is not currently used but it can come useful in the future
    [Documentation]  Returns a list of all OLTs known to ONOS
    [Arguments]  ${onos_ssh_connection}
    [Return]  ['of:00000a0a0a0a0a00', 'of:00000a0a0a0a0a01']
    ${result}=      Create List
    ${out}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
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

Count ADDED flows
    [Documentation]  Count the flows in ADDED state in ONOS
    [Arguments]  ${onos_ssh_connection}    ${targetFlows}   ${deviceId}
    ${flows}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...     flows -s any ${deviceId} | grep ADDED | wc -l
    Log     Found ${flows} of ${targetFlows} expected flows on device ${deviceId}
    Should Be Equal As Integers    ${targetFlows}    ${flows}

Wait for all flows to in ADDED state
    [Documentation]  Waits until the flows have been provisioned
    [Arguments]  ${onos_ssh_connection}     ${deviceId}     ${workflow}    ${uni_count}    ${olt_count}
    ...    ${provisioned}     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    ${targetFlows}=     Calculate flows by workflow     ${workflow}    ${uni_count}    ${olt_count}     ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    Wait Until Keyword Succeeds     10m     5s      Count ADDED flows
    ...     ${onos_ssh_connection}  ${targetFlows}  ${deviceId}

Get Bandwidth Details
    [Arguments]    ${bandwidth_profile_name}
    [Documentation]    Collects the bandwidth profile details for the given bandwidth profile and
    ...    returns the limiting bandwidth
    ${bandwidth_profile_values}=    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    bandwidthprofile ${bandwidth_profile_name}
    @{bandwidth_profile_array}=    Split String    ${bandwidth_profile_values}    ,
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[1]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${cir_value}    Run Keyword If    '${bandwidthparameter}' == ' committedInformationRate'
    ...    Set Variable    ${value}
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[2]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${cbs_value}    Run Keyword If    '${bandwidthparameter}' == ' committedBurstSize'    Set Variable    ${value}
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[3]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${eir_value}    Run Keyword If    '${bandwidthparameter}' == ' exceededInformationRate'   Set Variable    ${value}
    @{parameter_value_pair}=    Split String    ${bandwidth_profile_array[4]}    =
    ${bandwidthparameter}=    Set Variable    ${parameter_value_pair[0]}
    ${value}=    Set Variable    ${parameter_value_pair[1]}
    ${ebs_value}    Run Keyword If    '${bandwidthparameter}' == ' exceededBurstSize'    Set Variable    ${value}
    ${limiting_BW}=    Evaluate    ${cir_value}+${eir_value}
    [Return]    ${limiting_BW}

Validate Deleted Device Cleanup In ONOS
    [Arguments]    ${ip}    ${port}    ${olt_serial_number}
    [Documentation]    The keyword verifies that ports, flows, meters, subscribers, dhcp are all cleared in ONOS
    # Fetch OF Id for OLT
    ${olt_of_id}=    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device in ONOS    ${olt_serial_number}
    # Open ONOS SSH Connection
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ip}    ${port}
    # Verify Ports are Removed
    ${port_count}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    ports ${olt_of_id} | grep -v ${olt_of_id} | wc -l
    Should Be Equal As Integers    ${port_count}    0
    # Verify Subscribers are Removed
    ${sub_count}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    volt-programmed-subscribers | grep ${olt_of_id} | wc -l
    Should Be Equal As Integers    ${sub_count}    0
    # Verify Flows are Removed
    ${flow_count}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    flows -s -f ${olt_of_id} | grep -v deviceId | wc -l
    Should Be Equal As Integers    ${flow_count}    0
    # Verify Meters are Removed
    ${meter_count}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    meters ${olt_of_id} | wc -l
    Should Be Equal As Integers    ${meter_count}    0
    # Verify AAA-Users are Removed
    ${aaa_count}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    aaa-users ${olt_of_id} | wc -l
    Should Be Equal As Integers    ${aaa_count}    0
    # Verify Dhcp-Allocations are Removed
    ${dhcp_count}=    Execute ONOS CLI Command on open connection     ${onos_ssh_connection}
    ...    dhcpl2relay-allocations ${olt_of_id} | wc -l
    Should Be Equal As Integers    ${dhcp_count}    0
    # Close ONOS SSH Connection
    Close ONOS SSH Connection    ${onos_ssh_connection}
