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
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Resource          ./utils.robot
Resource          ./flows.robot

*** Keywords ***
Test Empty Device List
    [Documentation]    Verify that there are no devices in the system
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be Equal As Integers    ${length}    0

Create Device
    [Arguments]    ${ip}    ${port}     ${type}=openolt
    [Documentation]    Creates a device in VOLTHA
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device create -t ${type} -H ${ip}:${port}
    Log     ${device_id}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${device_id}

Enable Device
    [Arguments]    ${device_id}
    [Documentation]    Enables a device in VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device enable ${device_id}
    Should Be Equal As Integers    ${rc}    0

Disable Device
    [Arguments]    ${device_id}
    [Documentation]    Disables a device in VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device disable ${device_id}
    Should Be Equal As Integers    ${rc}    0

Delete Device
    [Arguments]    ${device_id}
    [Documentation]    Deletes a device in VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device delete ${device_id}
    Should Be Equal As Integers    ${rc}    0

Reboot Device
    [Arguments]    ${device_id}
    [Documentation]    Reboot the OLT using voltctl command
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device reboot ${device_id}
    Should Be Equal As Integers    ${rc}    0

Disable Devices In Voltha
    [Documentation]    Disables all the known devices in voltha
    [Arguments]    ${filter}
    ${arg}=    Set Variable    ${EMPTY}
    ${arg}=    Run Keyword If    len('${filter}'.strip()) != 0    Set Variable    --filter ${filter}
    ${rc}    ${devices}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device list -m 8MB ${arg} --orderby Root -q | xargs echo -n
    Should Be Equal As Integers    ${rc}    0
    ${rc}    ${output}=    Run Keyword If    len('${devices}') != 0    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device disable ${devices}
    Run Keyword If    len('${devices}') != 0    Should Be Equal As Integers    ${rc}    0

Test Devices Disabled In Voltha
    [Documentation]    Tests to verify that all devices in VOLTHA are disabled
    [Arguments]    ${filter}
    ${rc}    ${count}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device list -m 8MB --filter '${filter},AdminState!=DISABLED' -q | wc -l
    Should Be Equal As Integers    ${rc}    0
    Should Be Equal As Integers    ${count}    0

Delete Devices In Voltha
    [Documentation]    Disables all the known devices in voltha
    [Arguments]    ${filter}
    ${arg}=    Set Variable    ${EMPTY}
    ${arg}=    Run Keyword If    len('${filter}'.strip()) != 0    Set Variable    --filter ${filter}
    ${rc}    ${devices}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device list ${arg} -m 8MB --orderby Root -q | xargs echo -n
    Should Be Equal As Integers    ${rc}    0
    ${rc}    ${output}=    Run Keyword If    len('${devices}') != 0    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device delete ${devices}
    Run Keyword If    len('${devices}') != 0    Should Be Equal As Integers    ${rc}    0

Get Device Flows from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets device flows from VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device flows ${device_id} -m 8MB
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

Get Logical Device Output from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets logicaldevice flows and ports from VOLTHA
    ${rc1}    ${flows}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} logicaldevice flows ${device_id}
    ${rc2}    ${ports}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} logicaldevice port list ${device_id}
    Log    ${flows}
    Log    ${ports}
    Should Be Equal As Integers    ${rc1}    0
    Should Be Equal As Integers    ${rc2}    0

Get Device Output from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets device flows and ports from VOLTHA
    ${rc1}    ${flows}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device flows ${device_id} -m 8MB
    ${rc2}    ${ports}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port list ${device_id} -m 8MB
    Log    ${flows}
    Log    ${ports}
    Should Be Equal As Integers    ${rc1}    0
    Should Be Equal As Integers    ${rc2}    0

Get Device List from Voltha
    [Documentation]    Gets Device List Output from Voltha
    ${rc1}    ${devices}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} device list -m 8MB
    Log    ${devices}
    Should Be Equal As Integers    ${rc1}    0

Get Device List from Voltha by type
    [Documentation]    Gets Device List Output from Voltha applying filtering by device type
    [Arguments]  ${type}
    ${rc1}    ${devices}=    Run and Return Rc and Output
    ...     voltctl -c ${VOLTCTL_CONFIG} device list -m 8MB -f Type=${type} -o json
    Log    ${devices}
    Should Be Equal As Integers    ${rc1}    0
    Return From Keyword     ${devices}

Get Logical Device List from Voltha
    [Documentation]    Gets Logical Device List Output from Voltha (in json format)
    ${rc1}    ${devices}=    Run and Return Rc and Output
    ...   voltctl -c ${VOLTCTL_CONFIG} logicaldevice list -m 8MB -o json
    Log    ${devices}
    Should Be Equal As Integers    ${rc1}    0
    Return From Keyword     ${devices}

Validate Device
    [Documentation]
    ...    Parses the output of "voltctl device list" and inspects a device ${id}, specified as either
    ...    the serial number or device ID. Arguments are matched for device states of: "admin_state",
    ...    "oper_status", and "connect_status"
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${id}=${EMPTY}    ${onu_reason}=${EMPTY}    ${onu}=False
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} device list -m 8MB -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${jsonCamelCaseFieldnames}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key       ${value}      adminState
        ${astate}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    adminState
        ...    ELSE
        ...    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    operStatus
        ...    ELSE
        ...    Get From Dictionary    ${value}    operstatus
        ${cstatus}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    connectStatus
        ...    ELSE
        ...    Get From Dictionary    ${value}    connectstatus
        ${sn}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    serialNumber
        ...    ELSE
        ...    Get From Dictionary    ${value}    serialnumber
        ${devId}=    Get From Dictionary    ${value}    id
        ${mib_state}=    Get From Dictionary    ${value}    reason
        ${matched}=    Set Variable If    '${sn}' == '${id}' or '${devId}' == '${id}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match found for ${id} to validate device
    Log    ${value}
    Should Be Equal    '${astate}'    '${admin_state}'    Device ${sn} admin_state != ${admin_state}
    ...    values=False
    Should Be Equal    '${opstatus}'    '${oper_status}'    Device ${sn} oper_status != ${oper_status}
    ...    values=False
    Should Be Equal    '${cstatus}'    '${connect_status}'    Device ${sn} conn_status != ${connect_status}
    ...    values=False
    Run Keyword If    '${onu}' == 'True'    Should Be Equal    '${mib_state}'    '${onu_reason}'
    ...    Device ${sn} mib_state incorrect (${mib_state}) values=False

Validate OLT Device
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${id}=${EMPTY}
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${id}, specified
    ...    as either its serial numbner or device ID. Match on OLT Serial number or Device Id and inspect states
    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}    ${id}

Validate OLT Devices
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${ids}=${EMPTY}
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${id}, specified
    ...    as either its serial numbner or device ID. Match on OLT Serial number or Device Id and inspect states
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Validate Device    ${admin_state}    ${oper_status}    ${connect_status}    ${olt_device_id}
    END

Validate ONU Devices
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${List_ONU_Serial}
    ...    ${onu_reason}=omci-flows-pushed
    [Documentation]    Parses the output of "voltctl device list" and inspects device    ${List_ONU_Serial}
    ...    Iteratively match on each Serial number contained in ${List_ONU_Serial} and inspect
    ...    states including MIB state
    FOR    ${serial_number}    IN    @{List_ONU_Serial}
        Validate Device    ${admin_state}    ${oper_status}    ${connect_status}    ${serial_number}
        ...    onu_reason=${onu_reason}    onu=True
    END

Validate Device Port Types
    [Documentation]
    ...    Parses the output of voltctl device port list <device_id> and matches the port types listed
    [Arguments]    ${device_id}    ${pon_type}    ${ethernet_type}   ${all_active}=True
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port list ${device_id} -m 8MB -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${jsonCamelCaseFieldnames}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key       ${value}      adminState
        ${astate}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    adminState
        ...    ELSE
        ...    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    operStatus
        ...    ELSE
        ...    Get From Dictionary    ${value}    operstatus
        ${type}=    Get From Dictionary    ${value}    type
        Should Be Equal    '${astate}'    'ENABLED'    Device ${device_id} port admin_state != ENABLED    values=False
        Run Keyword If    ${all_active}    Should Be Equal    '${opstatus}'    'ACTIVE'
        ...    Device ${device_id} port oper_status != ACTIVE    values=False
        Should Be True    '${type}' == '${pon_type}' or '${type}' == '${ethernet_type}'
        ...    Device ${device_id} port type is neither ${pon_type} or ${ethernet_type}
    END

Validate OLT Port Types
    [Documentation]    Parses the output of voltctl device port list ${olt_device_id} and matches the port types listed
    [Arguments]    ${pon_type}    ${ethernet_type}
    Validate Device Port Types    ${olt_device_id}    ${pon_type}    ${ethernet_type}

Validate ONU Port Types
    [Arguments]    ${List_ONU_Serial}    ${pon_type}    ${ethernet_type}
    [Documentation]    Parses the output of voltctl device port list for each ONU SN listed in ${List_ONU_Serial}
    ...    and matches the port types listed
    FOR    ${serial_number}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${serial_number}
        # Only first UNI port is ACTIVE; the rest are in DISCOVERED operstatus
        Validate Device Port Types    ${onu_dev_id}    ${pon_type}    ${ethernet_type}   all_active=False
    END

Validate Device Flows
    [Arguments]    ${device_id}    ${flow_count}=${EMPTY}
    [Documentation]    Parses the output of voltctl device flows <device_id> and expects flow count > 0
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device flows ${device_id} -m 8MB -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Log    'Number of flows = ' ${length}
    Run Keyword If    '${flow_count}' == '${EMPTY}'    Should Be True    ${length} > 0
    ...    Number of flows for ${device_id} was 0
    ...    ELSE    Should Be True    ${length} == ${flow_count}
    ...    Number of flows for ${device_id} was not ${flow_count}

Validate OLT Flows
    [Arguments]    ${flow_count}=${EMPTY}    ${olt_device_id}=${EMPTY}
    [Documentation]    Parses the output of voltctl device flows ${olt_device_id}
    ...    and expects flow count == ${flow_count}
    Validate Device Flows    ${olt_device_id}    ${flow_count}

Validate ONU Flows
    [Arguments]    ${List_ONU_Serial}    ${flow_count}=${EMPTY}
    [Documentation]    Parses the output of voltctl device flows for each ONU SN listed in ${List_ONU_Serial}
    ...    and expects flow count == ${flow_count}
    FOR    ${serial_number}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${serial_number}
        Validate Device Flows    ${onu_dev_id}    ${flow_count}
    END

Validate ONU Devices With Duration
    [Documentation]
    ...    Parses the output of "voltctl device list" and inspects all devices ${List_ONU_Serial},
    ...    Iteratively match on each Serial number contained in ${List_ONU_Serial} and inspect
    ...    states including MIB state.
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_reason}
    ...    ${List_ONU_Serial}   ${startTime}    ${print2console}=False    ${output_file}=${EMPTY}
    ...    ${alternate_reason}=${EMPTY}
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} device list -m 8MB -o json
    Should Be Equal As Integers    ${rc}    0
    ${timeCurrent} =    Get Current Date
    ${timeTotalMs} =    Subtract Date From Date    ${timeCurrent}    ${startTime}    result_format=number
    ${jsondata}=    To Json    ${output}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${matched}=    Set Variable    False
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${jsonCamelCaseFieldnames}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key       ${value}      adminState
        ${astate}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    adminState
        ...    ELSE
        ...    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    operStatus
        ...    ELSE
        ...    Get From Dictionary    ${value}    operstatus
        ${cstatus}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    connectStatus
        ...    ELSE
        ...    Get From Dictionary    ${value}    connectstatus
        ${sn}=    Run Keyword If     ${jsonCamelCaseFieldNames}
        ...    Get From Dictionary    ${value}    serialNumber
        ...    ELSE
        ...    Get From Dictionary    ${value}    serialnumber
        ${mib_state}=    Get From Dictionary    ${value}    reason
        ${onu_id}=    Get Index From List    ${List_ONU_Serial}   ${sn}
        ${matched}=    Set Variable If    -1 != ${onu_id}    True    False
        ${matched}=    Set Variable If    '${astate}' == '${admin_state}'    ${matched}    False
        ${matched}=    Set Variable If    '${opstatus}' == '${oper_status}'    ${matched}    False
        ${matched}=    Set Variable If    '${cstatus}' == '${connect_status}'    ${matched}    False
        ${matched}=    Set Variable If    '${mib_state}' == '${onu_reason}' or '${mib_state}' == '${alternate_reason}'
        ...   ${matched}    False
        Run Keyword If    ${matched} and ${print2console}    Log
        ...    \r\nONU ${sn} reached the state ${onu_reason} after ${timeTotalMs} sec.    console=yes
        Run Keyword If    ${matched} and ('${output_file}'!='${EMPTY}')    Append To File    ${output_file}
        ...    \r\nONU ${sn} reached the state ${onu_reason} after ${timeTotalMs} sec.
        Run Keyword If    ${matched}    Remove Values From List    ${List_ONU_Serial}    ${sn}
    END
    Should Be Empty    ${List_ONU_Serial}    List ${List_ONU_Serial} not empty

Validate ONU Devices MIB State With Duration
    [Documentation]
    ...    Parses the output of "voltctl device list" and inspects all devices ${List_ONU_Serial},
    ...    Iteratively match on each Serial number contained in ${List_ONU_Serial} and inspect MIB state.
    [Arguments]    ${onu_reason}
    ...    ${List_ONU_Serial}   ${startTime}    ${print2console}=False    ${output_file}=${EMPTY}
    ${type} =    Set Variable    brcm_openomci_onu
    ${voltctl_commad} =    Catenate    SEPARATOR=
        ...    voltctl device list -m 8MB -f Type=${type} -f Reason=${onu_reason} --format '{{.SerialNumber}}'
    ${rc}    ${output}=    Run and Return Rc and Output    ${voltctl_commad}
    Should Be Equal As Integers    ${rc}    0
    ${timeCurrent} =    Get Current Date
    ${timeTotalMs} =    Subtract Date From Date    ${timeCurrent}    ${startTime}    result_format=number
    @{outputdata} =    Split String    ${output}
    ${outputlength} =    Get Length    ${outputdata}
    ${onulength} =    Get Length    ${List_ONU_Serial}
    ${Matches} =    Run Keyword If    ${outputlength}<=${onulength}
    ...    Compare Lists    ${outputdata}    ${List_ONU_Serial}
    ...    ELSE    Compare Lists    ${List_ONU_Serial}    ${outputdata}
    ${length} =    Get Length    ${Matches}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${sn}=    Get From List    ${Matches}    ${INDEX}
        Run Keyword If    ${print2console}    Log
        ...    \r\nONU ${sn} reached the state ${onu_reason} after ${timeTotalMs} sec.    console=yes
        Run Keyword If    ('${output_file}'!='${EMPTY}')    Append To File    ${output_file}
        ...    \r\nONU ${sn} reached the state ${onu_reason} after ${timeTotalMs} sec.
        Remove Values From List    ${List_ONU_Serial}    ${sn}
    END
    Should Be Empty    ${List_ONU_Serial}    List ${List_ONU_Serial} not empty

Validate ONU Device By Device Id
    [Documentation]
    ...    Parses the output of "voltctl device list" filtered by device id and inspects states including reason.
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_reason}    ${onu_id}
    ${cmd}    Catenate    voltctl -c ${VOLTCTL_CONFIG} device list --filter=Id=${onu_id} -m 8MB -o json
    ${rc}    ${output}=    Run and Return Rc and Output    ${cmd}
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    ${length}=    Get Length    ${jsondata}
    Should Be Equal As Integers    ${length}    1    No match found for ${onu_id} to validate device
    ${value}=    Get From List    ${jsondata}    0
    Log    ${value}
    ${jsonCamelCaseFieldnames}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key       ${value}      adminState
    ${astate}=    Run Keyword If     ${jsonCamelCaseFieldNames}
    ...    Get From Dictionary    ${value}    adminState
    ...    ELSE
    ...    Get From Dictionary    ${value}    adminstate
    ${opstatus}=    Run Keyword If     ${jsonCamelCaseFieldNames}
    ...    Get From Dictionary    ${value}    operStatus
    ...    ELSE
    ...    Get From Dictionary    ${value}    operstatus
    ${cstatus}=    Run Keyword If     ${jsonCamelCaseFieldNames}
    ...    Get From Dictionary    ${value}    connectStatus
    ...    ELSE
    ...    Get From Dictionary    ${value}    connectstatus
    ${sn}=    Run Keyword If     ${jsonCamelCaseFieldNames}
    ...    Get From Dictionary    ${value}    serialNumber
    ...    ELSE
    ...    Get From Dictionary    ${value}    serialnumber
    ${devId}=    Get From Dictionary    ${value}    id
    ${mib_state}=    Get From Dictionary    ${value}    reason
    Should Be Equal    '${devId}'    '${onu_id}'    No match found for ${onu_id} to validate device
    ...    values=False
    Should Be Equal    '${astate}'    '${admin_state}'    Device ${sn} admin_state != ${admin_state}
    ...    values=False
    Should Be Equal    '${opstatus}'    '${oper_status}'    Device ${sn} oper_status != ${oper_status}
    ...    values=False
    Should Be Equal    '${cstatus}'    '${connect_status}'    Device ${sn} conn_status != ${connect_status}
    ...    values=False
    Should Be Equal    '${mib_state}'    '${onu_reason}'
    ...    Device ${sn} mib_state incorrect (${mib_state}) values=False


Compare Lists
    [Documentation]
    ...    Compares both lists and put all matches in the returned list
    [Arguments]    ${ListIterate}    ${ListCompare}
    @{list} =    Create List
    ${length} =    Get Length    ${ListIterate}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${sn}=    Get From List    ${ListIterate}    ${INDEX}
        ${onu_id}=    Get Index From List    ${ListCompare}   ${sn}
        Run Keyword If    -1 != ${onu_id}    Append To List    ${list}    ${sn}
    END
    [Return]    ${list}

Validate Logical Device
    [Documentation]    Validate Logical Device is listed
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} logicaldevice list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${devid}=    Get From Dictionary    ${value}    id
        ${rootdev}=    Get From Dictionary    ${value}    rootDeviceId
        ${desc}=    Get From Dictionary    ${value}    desc
        ${sn}=    Get From Dictionary    ${desc}    serialNum
        Exit For Loop
    END
    Should Be Equal    '${rootdev}'    '${olt_device_id}'    Root Device does not match ${olt_device_id}    values=False
    Should Be Equal    '${sn}'    '${BBSIM_OLT_SN}'    Logical Device ${sn} does not match ${BBSIM_OLT_SN}
    ...    values=False
    [Return]    ${devid}

Validate Logical Device Ports
    [Arguments]    ${logical_device_id}
    [Documentation]    Validate Logical Device Ports are listed and are > 0
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} logicaldevice port list ${logical_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True    ${length} > 0    Number of ports for ${logical_device_id} was 0

Validate Logical Device Flows
    [Arguments]    ${logical_device_id}
    [Documentation]    Validate Logical Device Flows are listed and are > 0
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} logicaldevice flows ${logical_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True    ${length} > 0    Number of flows for ${logical_device_id} was 0

Retrieve OLT PON Ports
    [Arguments]    ${olt_device_id}
    [Documentation]    Retrieves the list of PON ports from the OLT device
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port list ${olt_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${olt_pon_list}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${portno}=    Get From Dictionary    ${value}    portNo
        ${peers}=    Get From Dictionary    ${value}    peers
        ${len_peers}=    Get Length    ${peers}
        Run Keyword If    '${type}' == 'PON_OLT' and ${len_peers} > 0
        ...    Append To List    ${olt_pon_list}    ${portno}
    END
    [Return]    ${olt_pon_list}

Retrieve Peer List From OLT PON Port
    [Arguments]    ${olt_device_id}    ${pon_port}
    [Documentation]    Retrieves the list of peer device ids list from the OLT PON port
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port list ${olt_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${portno}=    Get From Dictionary    ${value}    portNo
        ${peers}=    Get From Dictionary    ${value}    peers
        ${matched}=    Set Variable If    '${type}' == 'PON_OLT' and '${portno}' == '${pon_port}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No PON port found for OLT ${olt_device_id}
    ${length}=    Get Length    ${peers}
    ${olt_peer_list}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${peers}    ${INDEX}
        ${peer_id}=    Get From Dictionary    ${value}    deviceId
        Append To List    ${olt_peer_list}    ${peer_id}
    END
    [Return]    ${olt_peer_list}

Validate OLT PON Port Status
    [Arguments]    ${olt_device_id}    ${pon_port}    ${admin_state}    ${oper_status}
    [Documentation]    Verifies the state of the PON port of the OLT
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port list ${olt_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${portno}=    Get From Dictionary    ${value}    portNo
        ${astate}=    Get From Dictionary    ${value}    adminState
        ${opstatus}=    Get From Dictionary    ${value}    operStatus
        ${matched}=    Set Variable If    '${type}' == 'PON_OLT' and '${portno}' == '${pon_port}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No PON port found for OLT ${olt_device_id} ${pon_port}
    Log    ${value}
    Should Be Equal    '${astate}'    '${admin_state}'    OLT PON Port admin_state != ${admin_state}
    ...    values=False
    Should Be Equal    '${opstatus}'    '${oper_status}'    OLT PON Port oper_status != ${oper_status}
    ...    values=False

DisableOrEnable OLT PON Port
    [Arguments]    ${operation}    ${olt_device_id}    ${portno}
    [Documentation]    Disables or Enables the PON port of the OLT
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port ${operation} ${olt_device_id} ${portno}
    Should Be Equal As Integers    ${rc}    0

Retrieve Peer List From OLT
    [Arguments]    ${olt_peer_list}
    [Documentation]    Retrieve the list of peer device id list from port list
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port list ${olt_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${peers}=    Get From Dictionary    ${value}    peers
        ${matched}=    Set Variable If    '${type}' == 'PON_OLT'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No PON port found for OLT ${olt_device_id}
    ${length}=    Get Length    ${peers}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${peers}    ${INDEX}
        ${peer_id}=    Get From Dictionary    ${value}    deviceId
        Append To List    ${olt_peer_list}    ${peer_id}
    END

Validate OLT Peer Id List
    [Arguments]    ${olt_peer_id_list}
    [Documentation]    Match each entry in the ${olt_peer_id_list} against ONU device ids.
    FOR    ${peer_id}    IN    @{olt_peer_id_list}
        Match OLT Peer Id    ${peer_id}
    END

Match OLT Peer Id
    [Arguments]    ${olt_peer_id}
    [Documentation]    Lookup the OLT Peer Id in against the list of ONU device Ids
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${devid}=    Get From Dictionary    ${value}    id
        ${matched}=    Set Variable If    '${devid}' == '${olt_peer_id}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    Peer id ${olt_peer_id} does not match any ONU device id

Validate ONU Peer Id
    [Arguments]    ${olt_device_id}    ${List_ONU_Serial}
    [Documentation]    Match each ONU peer to that of the OLT device id
    FOR    ${onu_serial}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${onu_serial}
        Match ONU Peer Id    ${onu_dev_id}
    END

Match ONU Peer Id
    [Arguments]    ${onu_dev_id}
    [Documentation]    Match an ONU peer to that of the OLT device id
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device port list ${onu_dev_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${peers}=    Get From Dictionary    ${value}    peers
        ${matched}=    Set Variable If    '${type}' == 'PON_ONU'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No PON port found for ONU ${onu_dev_id}
    ${length}=    Get Length    ${peers}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${peers}    ${INDEX}
        ${peer_id}=    Get From Dictionary    ${value}    deviceId
    END
    Should Be Equal    '${peer_id}'    '${olt_device_id}'
    ...    Mismatch between ONU peer ${peer_id} and OLT device id ${olt_device_id}    values=False

Get Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${rc}    ${id}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device list --filter=SerialNumber=${serial_number} --format='{{.Id}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${id}
    [Return]    ${id}

Get Logical Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${rc}    ${id}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} logicaldevice list --filter=Desc.SerialNum=${serial_number} --format='{{.Id}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${id}
    [Return]    ${id}

Build ONU SN List
    [Arguments]    ${serial_numbers}    ${olt_serial_number}=${EMPTY}    ${num_onus}=${num_all_onus}
    [Documentation]    Appends all ONU SNs for the given OLT to the ${serial_numbers} list
    FOR    ${INDEX}    IN RANGE    0    ${num_onus}
    Run Keyword IF  "${olt_serial_number}"=="${hosts.src[${INDEX}].olt}" or "${olt_serial_number}"=="${EMPTY}"
    ...   Append To List    ${serial_numbers}    ${hosts.src[${INDEX}].onu}
    END

Get SN From Device ID
    [Arguments]    ${device_id}
    [Documentation]    Gets the device id by matching for ${device_id}
    ${rc}    ${sn}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device list --filter=Id=${device_id} --format='{{.SerialNumber}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${sn}
    [Return]    ${sn}

Get Parent ID From Device ID
    [Arguments]    ${device_id}
    [Documentation]    Gets the device id by matching for ${device_id}
    ${rc}    ${pid}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device list --filter=Id=${device_id} --format='{{.ParentId}}'
    Should Be Equal As Integers    ${rc}    0
    Log    ${pid}
    [Return]    ${pid}

Validate Device Removed
    [Arguments]    ${id}
    [Documentation]    Verifys that device, ${serial_number}, has been removed
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    @{ids}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${device_id}=    Get From Dictionary    ${value}    id
        Append To List    ${ids}    ${device_id}
    END
    List Should Not Contain Value    ${ids}    ${id}

Validate all ONUS for OLT Removed
    [Arguments]    ${num_all_onus}    ${hosts}    ${olt_serial_number}    ${timeout}
    [Documentation]    Verifys that all the ONUS for OLT ${serial_number}, has been removed
    FOR    ${J}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${J}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device Removed    ${src['onu']}
    END

Reboot ONU
    [Arguments]    ${onu_id}    ${validate_device}=True
    [Documentation]   Using voltctl command reboot ONU and verify that ONU comes up to running state
    ${rc}    ${devices}=    Run and Return Rc and Output    voltctl -c ${VOLTCTL_CONFIG} device reboot ${onu_id}
    Should Be Equal As Integers    ${rc}    0
    Run Keyword If    ${validate_device}    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds
    ...    60s   1s    Validate ONU Device By Device Id    ENABLED    DISCOVERED    REACHABLE    rebooting   ${onu_id}

Assert ONUs in Voltha
    [Arguments]    ${count}
    [Documentation]    Check that a certain number of devices reached the ACTIVE/ENABLE state
    ${rc1}    ${devices}=    Run and Return Rc and Output
    ...     voltctl -c ${VOLTCTL_CONFIG} -m 8M device list | grep -v OLT | grep ACTIVE | wc -l
    Should Be Equal As Integers    ${rc1}    0
    Should Be Equal As Integers    ${devices}    ${count}

Wait for ONUs in VOLTHA
    [Arguments]    ${count}
    [Documentation]    Waits until a certain number of devices reached the ACTIVE/ENABLE state
    Wait Until Keyword Succeeds     10m     5s      Assert ONUs In Voltha   ${count}

Count Logical Devices flows
    [Documentation]  Count the flows across logical devices in VOLTHA
    [Arguments]  ${targetFlows}
    ${output}=     Get Logical Device List From Voltha
    ${logical_devices}=    To Json    ${output}
    ${total_flows}=     Set Variable    0
    FOR     ${device}   IN  @{logical_devices}
        ${rc}    ${flows}=    Run and Return Rc and Output
        ...    voltctl -c ${VOLTCTL_CONFIG} logicaldevice flows ${device['id']} | grep -v ID | wc -l
        Should Be Equal As Integers    ${rc}    0
        ${total_flows}=     Evaluate    ${total_flows} + ${flows}
    END
    ${msg}=     Format String   Found {total_flows} flows of {targetFlows} expected
    ...     total_flows=${total_flows}  targetFlows=${targetFlows}
    Log     ${msg}
    Should Be Equal As Integers    ${targetFlows}    ${total_flows}

Wait for Logical Devices flows
    [Documentation]  Waits until the flows have been provisioned in the logical device
    [Arguments]  ${workflow}    ${uni_count}    ${olt_count}    ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    ${targetFlows}=     Calculate flows by workflow     ${workflow}    ${uni_count}    ${olt_count}     ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}    ${withLldp}
    Log     ${targetFlows}
    # TODO extend Validate Logical Device Flows to check the correct number of flows
    Wait Until Keyword Succeeds     10m     5s  Count Logical Devices flows     ${targetFlows}

Count OpenOLT Device Flows
    [Documentation]  Count the flows across openolt devices in VOLTHA
    [Arguments]  ${targetFlows}
    ${output}=     Get Device List from Voltha by type      openolt
    ${devices}=    To Json    ${output}
    ${total_flows}=     Set Variable    0
    FOR     ${device}   IN  @{devices}
        ${rc}    ${flows}=    Run and Return Rc and Output
        ...     voltctl -c ${VOLTCTL_CONFIG} device flows ${device['id']} | grep -v ID | wc -l
        Should Be Equal As Integers    ${rc}    0
        ${total_flows}=     Evaluate    ${total_flows} + ${flows}
    END
    ${msg}=     Format String   Found {total_flows} flows of {targetFlows} expected
    ...     total_flows=${total_flows}  targetFlows=${targetFlows}
    Log     ${msg}
    Should Be Equal As Integers    ${targetFlows}    ${total_flows}

Wait for OpenOLT Devices flows
    [Documentation]  Waits until the flows have been provisioned in the openolt devices
    [Arguments]  ${workflow}    ${uni_count}    ${olt_count}    ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    ${beforeFlows}=     Calculate flows by workflow     ${workflow}    ${uni_count}    ${olt_count}     ${provisioned}
    ...     ${withEapol}    ${withDhcp}     ${withIgmp}     ${withLldp}
    # In the physical device we only have 2 data plane flows (on the PON) instead of 4
    ${afterFlows}=      Evaluate    ${beforeFlows} - (${uni_count} * 2)
    # In the TT workflow we have multiple service,
    # so we need to remove 6 flows per each UNI that are only on the ONU device
    ${ttFlows}=     Evaluate    ${beforeFlows} - (${uni_count} * 6)
    ${afterFlows}=    Set Variable If  $workflow=='tt'    ${ttFlows}   ${afterFlows}
    ${targetFlows}=    Set Variable If  $provisioned=='true'    ${afterFlows}   ${beforeFlows}
    Log     ${targetFlows}
    Wait Until Keyword Succeeds     10m     5s  Count OpenOLT Device Flows     ${targetFlows}
