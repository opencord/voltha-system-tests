# Copyright 2017-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
# vgc common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Variables ***
@{connection_list}
${alias}                  VGC_SSH
${ssh_read_timeout}       60s
${ssh_prompt}             karaf@root >
${ssh_regexp_prompt}      REGEXP:k.*a.*r.*a.*f.*@.*r.*o.*o.*t.* .*>.*
${regexp_prompt}          (?ms)(.*)k(.*)a(.*)r(.*)a(.*)f(.*)@(.*)r(.*)o(.*)o(.*)t(.*) (.*)>(.*)
${ssh_width}              400
${disable_highlighter}    setopt disable-highlighter
# ${keep_alive_interval} is set to 0s means sending the keepalive packet is disabled!
${keep_alive_interval}    0s
${INFRA_DT_NAMESPACE}      infra


*** Keywords ***
Create VGC Session
    [Documentation]    Creates a VGC session
    Create Session    VGC    http://${VGC_REST_IP}:${VGC_REST_PORT}/vgc/v1

Validate OLT Device in VGC
    #    FIXME use volt-olts to check that the OLT is VGC
    [Arguments]    ${serial_number}
    [Documentation]    Checks if olt has been connected to VGC
    Create VGC Session
    ${resp}=    Get Request    VGC    devices
    Log     ${resp}
    ${jsondata}=    To Json   ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}       No devices data found in VGC
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



Validate Deleted Device Cleanup In VGC
    [Arguments]    ${ip}    ${port}    ${olt_serial_number}    ${olt_of_id}    ${maclearning_enabled}=False
    [Documentation]    The keyword verifies that ports, flows, meters, subscribers, dhcp are all cleared in VGC
    # Verify Ports are Removed
    ${ports}=    Get Request    VGC    devices/ports
    ${port_json_resp}=    To Json   ${ports.content}
    Should Not Contain    ${port_json_resp}     ${olt_of_id}    Ports have not been removed from VGC after cleanup
    # Verify Subscribers are Removed
    ${sub}=    Get Request    VGC    programmed-subscribers
    ${sub_json_resp}=    To Json   ${sub.content}
    Should Not Contain    ${sub_json_resp}     ${olt_of_id}   Subscriber have not been removed from VGC after cleanup
    # Verify Flows are Removed
    ${flows}=    Get Request    VGC    flows
    ${flow_json_resp}=    To Json   ${flows.content}
    Should Not Contain    ${flow_json_resp}     ${olt_of_id}    Flows have not been removed from VGC after cleanup
    # Verify Meters are Removed
    ${meter}=    Get Request    VGC    meters
    ${meter_json_resp}=    To Json   ${meter.content}
    Should Not Contain    ${meter_json_resp}     ${olt_of_id}   Meter have not been removed from VGC after cleanup
    # Verify AAA-Users are Removed
    # ${aaa}=    Execute ONOS CLI Command use single connection     ${ip}    ${port}
    #...    aaa-users ${olt_of_id}
    # ${aaa_count}=      Get Line Count      ${aaa}
    #Should Be Equal As Integers    ${aaa_count}    0    AAA Users have not been removed from ONOS after cleanup
    # Verify Dhcp-Allocations are Removed
    ${dhcp}=    Get Request    VGC    allocations/${olt_of_id}
    ${dhcp_json_resp}=    To Json   ${dhcp.content}
    ${dhcp_count} =    Get Length      ${dhcp_json_resp}
    #Should Be Equal    ${dhcp_json_resp}     ${None}     DHCP Allocations have not been removed from VGC after cleanup
    Should Be Equal As Integers    ${dhcp_count}    0   DHCP Allocations have not been removed from VGC after cleanup
    # Verify MAC Learner Mappings are Removed
    # ${mac}=    Run Keyword If    ${maclearning_enabled}    Execute ONOS CLI Command use single connection     ${ip}    ${port}
    # ...    mac-learner-get-mapping | grep -v INFO
    # ${mac_count}=    Run Keyword If    ${maclearning_enabled}    Get Line Count    ${mac}
    # ...    ELSE    Set Variable    0
    # Should Be Equal As Integers    ${mac_count}    0   Client MAC Learner Mappings have not been removed from ONOS after cleanup


Get NNI Port in VGC
    [Arguments]    ${olt_of_id}
    [Documentation]    Retrieves NNI port for the OLT in VGC
    ${resp}=    Get Request    VGC    devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}     No ports data found for OLT ${olt_of_id} in VGC
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



Get ONU Port in VGC
    [Arguments]    ${onu_serial_number}    ${olt_of_id}    ${onu_uni_id}=1
    [Documentation]    Retrieves ONU port for the ONU in VGC
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_serial_number}    ${onu_uni_id}
    ${resp}=    Get Request    VGC    devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}     No ports data found for OLT ${olt_of_id} in VGC
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



Verify UNI Port Is Enabled
    [Arguments]      ${onu_name}    ${onu_uni_id}=1
    [Documentation]    Verifies if the ONU's UNI port is enabled in VGC
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_name}    ${onu_uni_id}
    ${resp}=    Get Request    VGC    devices/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}     No devices ports data in VGC
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${onu_port}=    Get From Dictionary    ${value}    port
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${portstatus}=    Get From Dictionary    ${value}    isEnabled
        ${matched}=    Set Variable If    '${portName}' == '${onu_serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${onu_serial_number} found
    Should be Equal 	${portstatus}     ${True}


Verify UNI Port Is Disabled
    [Arguments]      ${ip}    ${port}    ${onu_name}    ${onu_uni_id}=1
    [Documentation]    Verifies if the ONU's UNI port is enabled in VGC
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_name}    ${onu_uni_id}
    ${resp}=    Get Request    VGC    devices/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}     No devices ports data in VGC
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${onu_port}=    Get From Dictionary    ${value}    port
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${portstatus}=    Get From Dictionary    ${value}    isEnabled
        ${matched}=    Set Variable If    '${portName}' == '${onu_serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${onu_serial_number} found
    Should be Equal 	${portstatus}     ${False}

Close All VGC SSH Connections
    [Documentation]    Close all VGC Connection and clear connection list.
    SSHLibrary.Close All Connections
    @{connection_list}    Create List



Verify Subscriber Access Flows Added For ONU DT in VGC
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in VGC for the ONU
    # Get all flows from VGC
    ${resp}=    Get Request    VGC   flows/${olt_of_id}
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['flows']}     No flows data found for OLT ${olt_of_id} in VGC
    # Verify upstream table=0 flow
    ${length}=    Get Length    ${jsondata['flows']}
    @{flows}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${tableid}=     Get Table Id From Flow    ${flow}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${matched}=    Set Variable If
        ...    '${tableid}' == '0' and '${inport}' == '${onu_port}' and '${vlanvid}' == '4096' and '${outport}' == '1'
        ...    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for upstream table 0 flow found
    # Verify upstream table=1 flow
    ${matched1}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${subtype}=    Get Subtype From Flow   ${flow}
        ${vlanid}=     Get Vlan Id From Flow   ${flow}
        ${res1}=    Evaluate    '${inport}' == '${onu_port}'
        ${res2}=    Evaluate    '${vlanvid}' == '4096' and '${outport}' == '${nni_port}'
        ${res3}=    Evaluate    '${subtype}' == 'VLAN_PUSH' and '${vlanid}' == '${s_tag}'
        ${matched1}=     Set Variable If  ${res1} and ${res2} and ${res3}   True    False
        Exit For Loop If    ${matched1}
    END
    Should Be True    ${matched1}    No match for upstream table 1 flow found
    # Verify downstream table=0 flow
    ${matched2}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${subtype}=    Get Subtype From Flow   ${flow}
        ${res1}=    Evaluate    '${inport}' == '${nni_port}'
        ${res2}=    Evaluate    '${vlanvid}' == '${s_tag}' and '${outport}' == '1'
        ${res3}=    Evaluate    '${subtype}' == 'VLAN_POP'
        ${matched2}=     Set Variable If  ${res1} and ${res2} and ${res3}   True    False
        Exit For Loop If    ${matched2}
    END
    Should Be True    ${matched2}    No match for downstream table 0 flow found
    # Verify downstream table=1 flow
    ${matched3}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${matched3}=    Set Variable If
        ...  '${inport}' == '${nni_port}' and '${vlanvid}' == '4096' and '${outport}' == '${onu_port}'
        ...  True    False
        Exit For Loop If    ${matched3}
    END
    Should Be True    ${matched3}    "No match for downstream table 1 flow found"

Verify Subscriber Access Flows Added for DT FTTB
    [Arguments]    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}    ${c_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Get all flows from VGC
    ${resp}=    Get Request    VGC   flows/${olt_of_id}
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['flows']}     No ports data found for OLT ${olt_of_id} in VGC
    # Upstream
    # ONU
    ${length}=    Get Length    ${jsondata['flows']}
    @{flows}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${tableid}=     Get Table Id From Flow    ${flow}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${matched}=    Set Variable If
        ...    '${inport}' == '${onu_port}' and '${vlanvid}' == '${c_tag}' and '${outport}' == '1'
        ...    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for upstream ONU flow found
    # OLT
    ${matched1}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${vlanid}=     Get Vlan Id From Flow For Fttb   ${flow}
        ${res1}=    Evaluate    '${inport}' == '${onu_port}'
        ${res2}=    Evaluate    '${vlanvid}' == '${c_tag}' and '${vlanid}' == '${s_tag}'
        ${res3}=    Evaluate    '${outport}' == '${nni_port}'
        ${matched1}=     Set Variable If  ${res1} and ${res2} and ${res3}   True    False
        Exit For Loop If    ${matched1}
    END
    Should Be True    ${matched1}    No match for upstream OLT found
    # Downstream
    # OLT
    ${matched2}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${vlanid}=     Get Vlan Id From Flow For Fttb   ${flow}
        ${res1}=    Evaluate    '${inport}' == '${nni_port}'
        ${res2}=    Evaluate    '${vlanvid}' == '${s_tag}' and '${vlanid}' == '${c_tag}'
        ${res3}=    Evaluate    '${outport}' == '1'
        ${matched2}=     Set Variable If  ${res1} and ${res2} and ${res3}   True    False
        Exit For Loop If    ${matched2}
    END
    Should Be True    ${matched2}    No match for downstream OLT found
    # ONU
    ${matched3}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${tableid}=     Get Table Id From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${vlanid}=     Get Vlan Id From Flow For Fttb   ${flow}
        ${res1}=    Evaluate    '${inport}' == '${nni_port}'
        ${res2}=    Evaluate    '${vlanvid}' == '${c_tag}' and '${outport}' == '${onu_port}'
        ${matched3}=     Set Variable If  ${res1} and ${res2}   True    False
        Exit For Loop If    ${matched3}
    END
    Should Be True    ${matched3}    No match for downstream ONU found

Verify DPU MGMT Flows Added for DT FTTB
    [Arguments]    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}    ${c_tag}
    [Documentation]    Verifies if the DPU MGMT Flows are added in VGC for the ONU
    # Get all flows from VGC
    ${resp}=    Get Request    VGC   flows/${olt_of_id}
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['flows']}     No ports data found for OLT ${olt_of_id} in VGC
    # Upstream
    # ONU
    ${length}=    Get Length    ${jsondata['flows']}
    @{flows}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${tableid}=     Get Table Id From Flow    ${flow}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${vlanid}=     Get Vlan Id From Flow For Fttb   ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${res1}=    Evaluate    '${inport}' == '${onu_port}'
        ${res2}=    Evaluate    '${vlanvid}' == '${c_tag}' and '${vlanid}' == '${s_tag}'
        ${res3}=    Evaluate    '${outport}' == '1'
        ${matched}=     Set Variable If  ${res1} and ${res2} and ${res3}   True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for upstream ONU flow found
    # OLT
    ${matched1}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${vlanid}=     Get Vlan Id From Flow For Fttb   ${flow}
        ${matched1}=    Set Variable If
        ...    '${inport}' == '${onu_port}' and '${vlanvid}' == '${s_tag}' and '${outport}' == '${nni_port}'
        ...    True    False
        ${matched1}=     Set Variable If  ${res1} and ${res2} and ${res3}   True    False
        Log To Console  "bbb",'${inport}' == '${onu_port}' '${vlanvid}' == '${s_tag}' '${outport}' == '${nni_port}'
        Exit For Loop If    ${matched1}
    END
    Should Be True    ${matched1}    No match for upstream OLT found
    # Downstream
    # OLT
    ${matched2}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${vlanid}=     Get Vlan Id From Flow For Fttb   ${flow}
        ${matched3}=    Set Variable If
        ...    '${inport}' == '${nni_port}' and '${vlanvid}' == '${s_tag}' and '${outport}' == '1'
        ...    True    False
        Exit For Loop If    ${matched3}
    END
    Should Be True    ${matched3}    No match for downstream OLT found
    # ONU
    ${matched4}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${vlanvid}=    Get Vlan VId From Flow    ${flow}
        ${tableid}=     Get Table Id From Flow    ${flow}
        ${outport}=    Get Out Port From Flow    ${flow}
        ${vlanid}=     Get Vlan Id From Flow For Fttb   ${flow}
        ${res1}=    Evaluate    '${inport}' == '${nni_port}'
        ${res2}=    Evaluate    '${vlanvid}' == '${s_tag}' and '${vlanid}' == '${c_tag}'
        ${res3}=    Evaluate    '${outport}' == '${onu_port}'
        ${matched4}=     Set Variable If  ${res1} and ${res2} and ${res3}   True    False
        Exit For Loop If    ${matched4}
    END
    Should Be True    ${matched4}    No match for downstream ONU found

Verify VGC Flows Added for DT FTTB
    [Arguments]    ${olt_of_id}    ${onu_port}    ${nni_port}    ${service}
    [Documentation]    Verifies if the Flows are added in ONOS for the ONU
    ${num_services}=    Get Length    ${service}
    FOR     ${I}    IN RANGE    0    ${num_services}
        ${service_name}=    Set Variable    ${service[${I}]['name']}
        ${dpustag}=    Set Variable    ${service[0]['s_tag']}
        ${dpuctag}=    Set Variable    ${service[0]['c_tag']}
        ${stag}=    Set Variable    ${service[1]['s_tag']}
        ${ctag}=    Set Variable    ${service[1]['c_tag']}
        Run Keyword If    '${service_name}' == 'FTTB_SUBSCRIBER_TRAFFIC'   Run Keywords
             Verify Subscriber Access Flows Added for DT FTTB    ${olt_of_id}    ${onu_port}    ${nni_port}    ${stag}        ${ctag}
             Verify DPU MGMT Flows Added for DT FTTB    ${olt_of_id}    ${onu_port}    ${nni_port}    ${dpustag}    ${dpuctag}
    END

Add Subscriber Details
    [Documentation]    Adds a particular subscriber
    [Arguments]    ${of_id}    ${onu_port}
    ${resp}=    Post Request    VGC    services/${of_id}/${onu_port}
    Log   ${resp}
    Should Be Equal As Strings    ${resp.status_code}    200

Remove Subscriber Access
    [Documentation]    Removes a particular subscriber
    [Arguments]    ${of_id}    ${onu_port}
    ${resp}=    Delete Request    VGC    services/${of_id}/${onu_port}
    Log   ${resp}
    Should Be Equal As Strings    ${resp.status_code}    200

Send File To VGC
    [Documentation]    Send the content of the file to VGC to selected section of configuration
    ...   using Post Request
    [Arguments]    ${CONFIG_FILE}    ${dest}    #${section}=${EMPTY}
    ${Headers}=    Create Dictionary    Content-Type    application/json
    ${File_Data}=    OperatingSystem.Get File    ${CONFIG_FILE}
    Log    ${Headers}
    Log    ${File_Data}
    ${resp}=    Post Request    VGC
    ...    ${dest}    headers=${Headers}    data=${File_Data}
    Should Be Equal As Strings    ${resp.status_code}    200

Verify No Pending Flows For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that there are no flows "PENDING" state for the ONU in VGC
    ${resp}=    Get Request    VGC   flows/pending
    ${jsondata}=    To Json    ${resp.content}
    ${length}=    Get Length    ${jsondata['flows']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${flow}=    Get From List    ${jsondata['flows']}    ${INDEX}
        ${inport}=     Get In Port From Flow    ${flow}
        ${matched}=     Run Keyword If   '${inport}' == '${onu_port}'   Set Variable    ${TRUE}
        Exit For Loop If    ${matched}
    END
    Should Be Equal   ${matched}     False    No match for  pending flow  found

Get Pending Flow Count
    [Documentation]    Get the count for flows "PENDING" state for the ONU in VGC
    ${resp}=    Get Request    VGC   flows/pending
    ${jsondata}=    To Json    ${resp.content}
    ${length}=    Get Length    ${jsondata['flows']}
    [Return]    ${length}

Get In Port From Flow
    [Documentation]    Fetches the port Record for IN_PORT
    [Arguments]    ${flow}
    ${selector}=    Get From Dictionary    ${flow}    selector
    ${len}=    Get Length    ${selector['criteria']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${len}
           ${criteria}=    Get From List    ${selector['criteria']}    ${INDEX}
           ${type}=       Get From Dictionary    ${criteria}    type
           ${port}=     Run Keyword If    '${type}' == 'IN_PORT'       Get From Dictionary    ${criteria}    port
           ${matched}=    Set Variable If    '${type}' == 'IN_PORT'    True    False
           Exit For Loop If    ${matched}
    END
    [Return]    ${port}



Get Vlan VId From Flow
    [Documentation]    Fetches the vlan Id
    [Arguments]    ${flow}
    ${selector}=    Get From Dictionary    ${flow}    selector
    ${len}=    Get Length    ${selector['criteria']}
    ${matched}=    Set Variable    False
    ${vlanid}=     Set Variable
    FOR    ${INDEX}    IN RANGE    0    ${len}
           ${criteria}=    Get From List    ${selector['criteria']}    ${INDEX}
           ${type}=       Get From Dictionary    ${criteria}    type
           ${vlanid}=     Run Keyword If    '${type}' == 'VLAN_VID'       Get From Dictionary    ${criteria}    vlanId
           ${matched}=    Set Variable If    '${type}' == 'VLAN_VID'    True    False
           Exit For Loop If    ${matched}
    END
    [Return]    ${vlanid}


Get Out Port From Flow
    [Documentation]    Fetches the port for OUTPUT
    [Arguments]    ${flow}
    ${treatment}=    Get From Dictionary    ${flow}    treatment
    ${len}=    Get Length    ${treatment['instructions']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${len}
           ${instructions}=    Get From List    ${treatment['instructions']}    ${INDEX}
           ${type}=       Get From Dictionary    ${instructions}    type
           ${outport}=    Run Keyword If    '${type}' == 'OUTPUT'      Get From Dictionary    ${instructions}    port
           ${matched}=    Set Variable If    '${type}' == 'OUTPUT'    True    False
           Exit For Loop If    ${matched}
    END
    [Return]    ${outport}


Get Subtype From Flow
    [Documentation]    Fetches the L2MODIFICATION subtype
    [Arguments]    ${flow}
    ${treatment}=    Get From Dictionary    ${flow}    treatment
    ${len}=    Get Length    ${treatment['instructions']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${len}
           ${instructions}=    Get From List    ${treatment['instructions']}    ${INDEX}
           ${type}=       Get From Dictionary    ${instructions}    type
           ${subtype}=    Run Keyword If    '${type}' == 'L2MODIFICATION'      Get From Dictionary    ${instructions}    subtype
           ${matched}=    Set Variable If    '${type}' == 'L2MODIFICATION'   True    False
           Exit For Loop If    ${matched}
    END
    [Return]    ${subtype}

Get Vlan Id From Flow For Fttb
    [Documentation]    Fetch the VLAN id for L2MODIFICATION
    [Arguments]    ${flow}
    ${treatment}=    Get From Dictionary    ${flow}    treatment
    ${len}=    Get Length    ${treatment['instructions']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${len}
           ${instructions}=    Get From List    ${treatment['instructions']}    ${INDEX}
           ${type}=       Get From Dictionary    ${instructions}    type
           ${subtype}=    Run Keyword If    '${type}' == 'L2MODIFICATION'      Get From Dictionary    ${instructions}    subtype
           ${vlanId}=    Run Keyword If    '${type}' == 'L2MODIFICATION' and '${subtype}' == 'VLAN_SET'
           ...    Get From Dictionary    ${instructions}    vlanId
           ${matched}=    Set Variable If    '${type}' == 'L2MODIFICATION' and '${subtype}' == 'VLAN_SET'   True    False
           Exit For Loop If    ${matched}
    END
    [Return]      ${vlanId}

Get Table Id From Flow
    [Documentation]    Fetch the TableId
    [Arguments]    ${flow}
    ${tableid}=    Get From Dictionary    ${flow}    tableId
    [Return]    ${tableid}

Get Vlan Id From Flow
    [Documentation]    Fetch the VLAN id for L2MODIFICATION
    [Arguments]    ${flow}
    ${treatment}=    Get From Dictionary    ${flow}    treatment
    ${len}=    Get Length    ${treatment['instructions']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${len}
           ${instructions}=    Get From List    ${treatment['instructions']}    ${INDEX}
           ${type}=       Get From Dictionary    ${instructions}    type
           ${subtype}=    Run Keyword If    '${type}' == 'L2MODIFICATION'      Get From Dictionary    ${instructions}    subtype
           ${vlanId}=    Run Keyword If    '${type}' == 'L2MODIFICATION' and '${subtype}' == 'VLAN_ID'
           ...    Get From Dictionary    ${instructions}    vlanId
           ${matched}=    Set Variable If    '${type}' == 'L2MODIFICATION' and '${subtype}' == 'VLAN_ID'   True    False
           Exit For Loop If    ${matched}
    END
    [Return]      ${vlanId}

Get Subscribers for a Particular Service
    [Documentation]    Filters the subscriber for a particular service
    [Arguments]    ${olt_of_id}    ${subscriber_json}    ${filter}
    ${subscribers_info}=    Get From Dictionary    ${subscriber_json}    subscribers
    ${num_subscribers}=    Get Length    ${subscribers_info}
    ${subscriber_list}    Create List
    Return From Keyword If  '${filter}' == '${EMPTY}'   ${subscribers_info}
    FOR    ${INDEX}    IN RANGE    0    ${num_subscribers}
        ${subscriber}=    Get From List    ${subscribers_info}    ${INDEX}
        ${res1}=    Evaluate    '${olt_of_id}' == '${subscriber["location"]}'
        ${tag_subscriber_info}=    Get From Dictionary    ${subscriber}    tagInfo
        ${ServiceName}=    Get From Dictionary    ${tag_subscriber_info}    serviceName
        ${res2}=    Evaluate    '${filter}' == '${ServiceName}'
        Run Keyword If    ${res1} and ${res2}
        ...    Append To List    ${subscriber_list}    ${subscriber}
        ${matched}=     Set Variable If  ${res1} and ${res2}   True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No matching subscriber for OLT
    [Return]    ${subscriber_list}

Get Programmed Subscribers
    [Arguments]    ${olt_of_id}    ${onu_port}    ${filter}=${EMPTY}
    [Documentation]    Retrieves the subscriber details at a given location
    ${programmed_sub}=      Get Request    VGC    programmed-subscribers
    ${programmed_sub_json_resp}=    To Json   ${programmed_sub.content}
    ${filtered_subscriber_list}=    Get Subscribers for a Particular Service    ${olt_of_id}    ${programmed_sub_json_resp}
    ...    ${filter}
    [Return]    ${filtered_subscriber_list}

Verify Programmed Subscribers DT FTTB
    [Arguments]    ${olt_of_id}    ${onu_port}    ${service}
    [Documentation]    Verifies the subscriber is present at a given location
    ${num_services}=    Get Length    ${service}
    FOR    ${I}    IN RANGE    0    ${num_services}
        ${service_name}=    Set Variable    ${service[${I}]['name']}
        ${programmed_subscriber}=    Get Programmed Subscribers    ${olt_of_id}    ${onu_port}
        ...    ${service_name}
        Log    ${programmed_subscriber}
        Should Not Be Empty    ${programmed_subscriber}     No programmed subscribers found for ${service_name}
    END

Verify Meters in VGC Ietf
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${filter}=${EMPTY}
    [Documentation]    Verifies the meters with BW Ietf format (currently, DT workflow uses this format)
    ${programmed_sub_json_resp}=    Get Programmed Subscribers    ${olt_of_id}    ${onu_port}
    ...    ${filter}
    Log    ${programmed_sub_json_resp}
    ${us_bw_profile}    ${ds_bw_profile}    Get Upstream and Downstream Bandwidth Profile Name
    ...    ${programmed_sub_json_resp}
    # Get upstream bandwidth profile details
    ${us_cir}    ${us_cbs}    ${us_pir}    ${us_pbs}    ${us_gir}    Get Bandwidth Profile Details Ietf Rest
    ...    ${us_bw_profile}
    # Verify meter for upstream bandwidth profile
    ${meter}=      Get Request    VGC    meters
    ${meter_json_resp}=    To Json   ${meter.content}
    Log    ${meter_json_resp}
    ${rate}    ${burst_size}   Get Meter Param In Details
    ...    ${meter_json_resp}  1
    Log    ${rate}
    Log    ${burst_size}
    # for cir & cbs
    ${matched}=    Set Variable If    '${rate}' == '${us_cir}' and '${burst_size}' == '${us_cbs}'   True    False
    Should Be True    ${matched}
    ${res1}=    Evaluate    '${rate}' == '${us_cir}' and '${burst_size}' == '${us_cbs}'
    #for pir & pbs
    ${rate}    ${burst_size}   Get Meter Param In Details
    ...    ${meter_json_resp}  2
    ${matched}=    Set Variable If    '${rate}' == '${us_pir}' and '${burst_size}' == '${us_pbs}'   True    False
    Should Be True    ${matched}
    ${res2}=    Evaluate    '${rate}' == '${us_pir}' and '${burst_size}' == '${us_pbs}'
    #for gir
    Run Keyword if  ${us_gir} != 0    Validate Guarenteed Information Rate    ${us_gir}  ${meter_json_resp}
    # Get downstream bandwidth profile details
    ${ds_cir}    ${ds_cbs}    ${ds_pir}    ${ds_pbs}    ${ds_gir}    Get Bandwidth Profile Details Ietf Rest
    ...    ${ds_bw_profile}
    # Verify meter for downstream bandwidth profile
    ${meter}=      Get Request    VGC    meters
    ${meter_json_resp}=    To Json   ${meter.content}
    Log    ${meter_json_resp}
    ${rate}    ${burst_size}   Get Meter Param In Details
    ...    ${meter_json_resp}  1
    Log    ${rate}
    Log    ${burst_size}
    # for cir & cbs
    ${matched}=    Set Variable If    '${rate}' == '${ds_cir}' and '${burst_size}' == '${ds_cbs}'    True    False
    Should Be True    ${matched}
    #for pir & pbs
    ${rate}    ${burst_size}   Get Meter Param In Details
    ...    ${meter_json_resp}  2
    ${matched}=    Set Variable If    '${rate}' == '${ds_pir}' and '${burst_size}' == '${ds_pbs}'  True    False
    Should Be True    ${matched}
    #for gir
    Run Keyword If    ${ds_gir} != 0
    ...    Validate Guarenteed Information Rate    ${ds_gir}  ${meter_json_resp}

Verify Meters in VGC Ietf For FTTB Subscribers
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${filter}=${EMPTY}
    [Documentation]    Verifies the meters with BW Ietf format for FTTB Subscriber (currently, DT workflow uses this format)
    ${programmed_sub_json_resp}=    Get Programmed Subscribers    ${olt_of_id}    ${onu_port}
    ...    ${filter}
    Log    ${programmed_sub_json_resp}
    ${us_bw_profile}    ${ds_bw_profile}    Get Upstream and Downstream Bandwidth Profile Name
    ...    ${programmed_sub_json_resp}
    # Get upstream bandwidth profile details
    ${us_cir}    ${us_cbs}    ${us_pir}    ${us_pbs}    ${us_gir}    Get Bandwidth Profile Details Ietf Rest
    ...    ${us_bw_profile}
    # Verify meter for upstream bandwidth profile
    ${meter}=      Get Request    VGC    meters
    ${meter_json_resp}=    To Json   ${meter.content}
    ${meters}=    Get From Dictionary    ${meter_json_resp}    meters
    Log    ${meter_json_resp}
    Log    ${meters}
    ${meter_length}    Get Length    ${meters}
    FOR    ${i}    IN RANGE    ${meter_length}
        ${id}=    Get From Dictionary    ${meters[${i}]}    id
        Run Keyword If    '${id}' == '1'    Set Suite Variable    ${meter_json_resp}    ${meters[${i}]}
    END
    ${meter_json_Length}    Get Length    ${meter_json_resp['bands']}
    FOR    ${I}    IN RANGE    0     ${meter_json_Length}
        ${burst_size}=    Get From Dictionary    ${meter_json_resp['bands'][${I}]}    burstSize
        ${rate}=        Get From Dictionary    ${meter_json_resp['bands'][${I}]}    rate
        Log    ${rate}
        Log    ${burst_size}
        # for cir & cbs
        ${matched}=    Set Variable If    '${rate}' == '${us_cir}' and '${burst_size}' == '${us_cbs}'   True    False
        ${res1}=    Evaluate    '${rate}' == '${us_cir}' and '${burst_size}' == '${us_cbs}'
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}
    #for pir & pbs
    FOR    ${I}    IN RANGE    0     3
        ${burst_size}=    Get From Dictionary    ${meter_json_resp['bands'][${I}]}    burstSize
        ${rate}=        Get From Dictionary    ${meter_json_resp['bands'][${I}]}    rate
        ${matched}=    Set Variable If    '${rate}' == '${us_pir}' and '${burst_size}' == '${us_pbs}'   True    False
        ${res2}=    Evaluate    '${rate}' == '${us_pir}' and '${burst_size}' == '${us_pbs}'
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}
    #for gir
    Run Keyword if  ${us_gir} != 0    Validate Guarenteed Information Rate For FTTB    ${us_gir}  ${meter_json_resp}
    # Get downstream bandwidth profile details
    ${ds_cir}    ${ds_cbs}    ${ds_pir}    ${ds_pbs}    ${ds_gir}    Get Bandwidth Profile Details Ietf Rest
    ...    ${ds_bw_profile}
    ${meter}=      Get Request    VGC    meters
    ${meter_json_resp}=    To Json   ${meter.content}
    Log    ${meter_json_resp}
    Log    ${rate}
    Log    ${burst_size}
     ${meters}=    Get From Dictionary    ${meter_json_resp}    meters
     Log    ${meter_json_resp}
     Log    ${meters}
     FOR    ${i}    IN RANGE    2
         ${id}=    Get From Dictionary    ${meters[${i}]}    id
         Run Keyword If    '${id}' == '1'    Set Suite Variable    ${meter_json_resp}    ${meters[${i}]}
     END
     FOR    ${I}    IN RANGE    0     3
         ${burst_size}=    Get From Dictionary    ${meter_json_resp['bands'][${I}]}    burstSize
         ${rate}=        Get From Dictionary    ${meter_json_resp['bands'][${I}]}    rate
         Log    ${rate}
         Log    ${burst_size}
         # for cir & cbs
         ${matched}=    Set Variable If    '${rate}' == '${ds_cir}' and '${burst_size}' == '${ds_cbs}'   True    False
         ${res1}=    Evaluate    '${rate}' == '${ds_cir}' and '${burst_size}' == '${ds_cbs}'
         Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}

    # for cir & cbs
      FOR    ${I}    IN RANGE    0     3
          ${burst_size}=    Get From Dictionary    ${meter_json_resp['bands'][${I}]}    burstSize
          ${rate}=        Get From Dictionary    ${meter_json_resp['bands'][${I}]}    rate
          Log    ${rate}
          Log    ${burst_size}
          ${matched}=    Set Variable If    '${rate}' == '${ds_cir}' and '${burst_size}' == '${ds_cbs}'   True    False
          ${res1}=    Evaluate    '${rate}' == '${ds_pir}' and '${burst_size}' == '${ds_pbs}'
          Exit For Loop If    ${matched}
     END
     Should Be True    ${matched}
    #for pir & pbs
    #for gir
    Run Keyword If    ${ds_gir} != 0
    ...    Validate Guarenteed Information Rate For FTTB    ${ds_gir}  ${meter_json_resp}

Validate Guarenteed Information Rate
     [Documentation]    Validate gir for both upstream and downstream meters
     [Arguments]    ${gir}    ${meter_json_resp}
     ${rate}    ${burst_size}   Get Meter Param In Details
     ...    ${meter_json_resp}  3
     ${matched}=    Set Variable If    '${rate}' == '${gir}' and '${burst_size}' == '0'  True    False
     Should Be True    ${matched}
     [Return]    ${matched}

Validate Guarenteed Information Rate For FTTB
    [Documentation]    Validate gir for both upstream and downstream meters
    [Arguments]    ${gir}    ${meter_json_resp}
    ${burst_size}=    Get From Dictionary    ${meter_json_resp['bands'][2]}    burstSize
    ${rate}=    Get From Dictionary    ${meter_json_resp['bands'][2]}    rate
    ${matched}=    Set Variable If    '${rate}' == '${gir}' and '${burst_size}' == '0'  True    False
    Should Be True    ${matched}
    [Return]    ${matched}

Get Bandwidth Profile Details Ietf Rest
    [Arguments]    ${bw_profile_id}
    [Documentation]    Retrieves the details of the given Ietf standard based bandwidth profile using REST API
    ${bw_profile_id}=    Remove String    ${bw_profile_id}    '    "
    ${resp}=    Get Request    VGC    profiles/${bw_profile_id}
    Log     ${resp}
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata}      Could not find data for bandwidth profile ${bw_profile_id} in VGC
    ${matched}=    Set Variable    False
    ${bw_id}=    Get From Dictionary    ${jsondata}    id
    ${matched}=    Set Variable If    '${bw_id}' == '${bw_profile_id}'    True    False
    ${pir}=    Get From Dictionary    ${jsondata}    pir
    ${pbs}=    Get From Dictionary    ${jsondata}    pbs
    ${cir}=    Get From Dictionary    ${jsondata}    cir
    ${cbs}=    Get From Dictionary    ${jsondata}    cbs
    ${gir}=    Get From Dictionary    ${jsondata}    gir
    Should Be True    ${matched}    No bandwidth profile found for id: ${bw_profile_id}
    [Return]    ${cir}    ${cbs}    ${pir}    ${pbs}    ${gir}


Get Upstream and Downstream Bandwidth Profile Name
    [Arguments]    ${programmed_sub}
    [Documentation]    Retrieves the upstream and downstream bandwidth profile name
    ...    from the programmed subscriber
    ${length}=    Get Length    ${programmed_sub}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${programmed_sub}    ${INDEX}
        ${tagInfo_id}=    Get From Dictionary    ${value}    tagInfo
        Log    ${tagInfo_id}
        ${us_bw_profile}=    Get From Dictionary    ${tagInfo_id}    upstreamBandwidthProfile
        Log    ${us_bw_profile}
        ${ds_bw_profile}=    Get From Dictionary    ${tagInfo_id}    downstreamBandwidthProfile
        Log    ${ds_bw_profile}
    END
    [Return]    ${us_bw_profile}    ${ds_bw_profile}

Verify Subscriber Access Flows Added Count DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${expected_flows}
    [Documentation]    Matches for total number of subscriber access flows added for all onus
    ${resp}=    Get Request    VGC   flows/${olt_of_id}
    ${jsondata}=    To Json    ${resp.content}
    ${access_flows_added_count}=      Get Length      ${jsondata['flows']}
    Should Be Equal As Integers    ${access_flows_added_count}    ${expected_flows}

Get Meter Param In Details
    [Arguments]    ${meter_json}    ${length}
    [Documentation]    Retrieves the meter rate state burst-size
    ${metername}=    Get From Dictionary    ${meter_json}    meters
    Log    ${metername}
    ${value}=    Get From List    ${metername}  0
    ${bands_info}=    Get From Dictionary    ${value}    bands
    Log    ${bands_info}
    FOR    ${INDEX}    IN RANGE    0    ${length}
         ${value}=    Get From List    ${bands_info}    ${INDEX}
         ${burst_size}=    Get From Dictionary    ${value}    burstSize
         ${rate}=        Get From Dictionary    ${value}    rate
    END
    [Return]    ${rate}    ${burst_size}

Delete Subscribers And BW Profile In VGC
    [Documentation]    Delete Subscribers and bw profile  In VGC
    Create VGC Session
    ${resp}=    Get Request    VGC    programmed-subscribers
    Log     ${resp}
    ${jsondata}=    To Json   ${resp.content}
    ${length}=    Get Length    ${jsondata['subscribers']}
    @{serial_numbers}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['subscribers']}    ${INDEX}
        ${taginfo}=    Get From Dictionary    ${value}    tagInfo
        ${service_id}=    Get From Dictionary    ${taginfo}    serviceName
        ${upstream_bw_id}=    Get From Dictionary    ${taginfo}    upstreamBandwidthProfile
        ${downstream_bw_id}=    Get From Dictionary   ${taginfo}    downstreamBandwidthProfile
        Delete Request    VGC    subscribers/${service_id}
        Delete Request    VGC    profiles/${upstream_bw_id}
        Delete Request    VGC    profiles/${downstream_bw_id}
    END

Deactivate Subscribers In VGC
    [Documentation]    Deactivate Subscribers In VGC
    Create VGC Session
    ${resp}=    Get Request    VGC    devices/ports
    Log     ${resp}
    ${jsondata}=    To Json   ${resp.content}
    ${length}=    Get Length    ${jsondata['ports']}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${portname}=    Get From Dictionary    ${annotations}    portName
        Delete Request    VGC    services/${portname}
    END

Verify Device Flows Removed
    [Arguments]    ${ip}    ${port}    ${olt_of_id}
    [Documentation]    Verifies all flows are removed from the device
    ${resp}=    Get Request    VGC   flows/${olt_of_id}
    ${jsondata}=    To Json    ${resp.content}
    ${flow_count}=      Get Length      ${jsondata['flows']}
    Should Be Equal As Integers    ${flow_count}    0     Flows not removed

Device Is Available In VGC
    [Arguments]      ${olt_of_id}    ${available}=True
    [Documentation]    Validates the device exists and it has the expected availability in VGC
    ${resp}=    Get Request    VGC    devices
    ${jsondata}=    To Json   ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}   No devices data found in VGC
    ${length}=    Get Length    ${jsondata['devices']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${availability}=    Get From Dictionary    ${value}    available
        Log    ${olt_of_id}
        Log    ${of_id}
        ${matched}=    Set Variable If    '${of_id}' == '${olt_of_id}' and '${availability}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for '${olt_of_id}' found

