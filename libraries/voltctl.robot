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
Library           HttpLibrary.HTTP
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Create Device
    [Arguments]    ${ip}    ${port}
    [Documentation]    Parses the output of "voltctl device list" and inspects device serial number
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${ip}:${port}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${device_id}

Enable Device
    [Arguments]    ${device_id}
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device enable ${device_id}
    Should Be Equal As Integers    ${rc}    0

Validate Device
    [Arguments]  ${admin_state}  ${oper_status}  ${connect_status}  ${serial_number}=${EMPTY}  ${device_id}=${EMPTY}
    ...    ${onu_reason}=${EMPTY}   ${onu}=False
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${serial_number}
    ...    Arguments are matched for device states of: "admin_state", "oper_status", and "connect_status"
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${astate}=    Get From Dictionary    ${value}    adminstate
    \    ${opstatus}=    Get From Dictionary    ${value}    operstatus
    \    ${cstatus}=    Get From Dictionary    ${value}    connectstatus
    \    ${sn}=    Get From Dictionary    ${value}    serialnumber
    \    ${devId}=    Get From Dictionary    ${value}    id
    \    ${mib_state}=    Get From Dictionary    ${value}    reason
    \   Run Keyword If    '${sn}' == '${serial_number}' or '${devId}' == '${device_id}'    Exit For Loop
    Should Be Equal    '${astate}'    '${admin_state}'    Device ${serial_number} admin_state != ENABLED    values=False
    Should Be Equal    '${opstatus}'    '${oper_status}'    Device ${serial_number} oper_status != ACTIVE    values=False
    Should Be Equal    '${cstatus}'    '${connect_status}'    Device ${serial_number} connect_status != REACHABLE    values=False
    Run Keyword If    '${onu}' == 'True'    Should Be Equal    '${mib_state}'    '${onu_reason}'
    ...  Device ${serial_number} mib_state incorrect  values=False

Validate OLT Device
    [Documentation]  Parses the output of "voltctl device list" and inspects device ${serial_number} and/or  ${device_id}
    ...     Match on OLT Serial number or Device Id and inspect states
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}   ${serial_number}=${EMPTY}   ${device_id}=${EMPTY}
    Validate Device  ${admin_state}    ${oper_status}    ${connect_status}   ${serial_number}   ${device_id}

Validate ONU Devices
    [Documentation]  Parses the output of "voltctl device list" and inspects device  ${serial_number}
    ...     Iteratively match on each Serial number contained in ${List_ONU_Serial} and inspect states including MIB state
    [Arguments]  ${List_ONU_Serial}    ${admin_state}    ${oper_status}    ${connect_status}
    : For   ${serial_number}  IN  @{List_ONU_Serial}
    \   Validate Device  ${admin_state}    ${oper_status}    ${connect_status}   ${serial_number}
    ...  onu_reason=tech-profile-config-download-success    onu=True

Validate Device Port Types
    [Documentation]  Parses the output of voltctl device ports <device_id> and matches the port types listed
    [Arguments]  ${device_id}   ${pon_type}     ${ethernet_type}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device ports ${device_id} -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${astate}=    Get From Dictionary    ${value}    adminstate
    \    ${opstatus}=    Get From Dictionary    ${value}    operstatus
    \    ${type}=    Get From Dictionary    ${value}    type
    \   Should Be Equal    '${astate}'    'ENABLED'    Device ${device_id} port admin_state != ENABLED    values=False
    \   Should Be Equal    '${opstatus}'    'ACTIVE'    Device ${device_id} port oper_status != ACTIVE    values=False
    \   Should Be True    '${type}' == '${pon_type}' or '${type}' == '${ethernet_type}'
    ...     Device ${device_id} port type is neither ${pon_type} or ${ethernet_type}

Validate OLT Port Types
    [Documentation]  Parses the output of voltctl device ports ${olt_device_id} and matches the port types listed
    [Arguments]     ${pon_type}     ${ethernet_type}
    Validate Device Port Types   ${olt_device_id}    ${pon_type}     ${ethernet_type}

Validate ONU Port Types
    [Documentation]  Parses the output of voltctl device ports for each ONU SN listed in ${List_ONU_Serial} and matches the port types
    ...  listed
    [Arguments]     ${List_ONU_Serial}  ${pon_type}     ${ethernet_type}
    : For   ${serial_number}  IN  @{List_ONU_Serial}
    \   ${onu_dev_id}=  Get Device ID From SN   ${serial_number}
    \   Validate Device Port Types  ${onu_dev_id}    ${pon_type}     ${ethernet_type}

Validate Device Flows
    [Documentation]  Parses the output of voltctl device flows <device_id> and expects flow count > 0
    [Arguments]  ${device_id}   ${test}=${EMPTY}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device flows ${device_id} -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Log     'Number of flows = ' ${length}
    Run Keyword If  '${test}' == '${EMPTY}'     Should Be True  ${length} > 0   Number of flows for ${device_id} was 0
    ...  ELSE IF    '${test}' == 'ZERO'     Should Be True  ${length} == 0  Number of flows for ${device_id} was greater than 0

Validate OLT Flows
    [Documentation]  Parses the output of voltctl device flows ${olt_device_id} and expects flow count > 0
    Validate Device Flows   ${olt_device_id}

Validate ONU Flows
    [Documentation]  Parses the output of voltctl device flows for each ONU SN listed in ${List_ONU_Serial} and expects flow count == 0
    [Arguments]     ${List_ONU_Serial}      ${test}
    : For   ${serial_number}  IN  @{List_ONU_Serial}
    \   ${onu_dev_id}=  Get Device ID From SN   ${serial_number}
    \   Validate Device Flows  ${onu_dev_id}    ${test}

Validate Logical Device
    [Documentation]  Validate Logical Device is listed
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl logicaldevice list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \   ${value}=    Get From List    ${jsondata}    ${INDEX}
    \   ${devid}=  Get From Dictionary    ${value}   id
    \   ${rootdev}=  Get From Dictionary    ${value}   rootdeviceid
    \   ${sn}=  Get From Dictionary    ${value}   serialnumber
    \   Exit For Loop
    Should Be Equal    '${rootdev}'    '${olt_device_id}'    Root Device does not match ${olt_device_id}    values=False
    Should Be Equal    '${sn}'    '${BBSIM_OLT_SN}'    Logical Device ${sn} does not match ${BBSIM_OLT_SN}    values=False
    [Return]  ${devid}

Validate Logical Device Ports
    [Documentation]  Validate Logical Device Ports are listed and are > 0
    [Arguments]  ${logical_device_id}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl logicaldevice ports ${logical_device_id} -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True  ${length} > 0   Number of ports for ${logical_device_id} was 0

Validate Logical Device Flows
    [Documentation]  Validate Logical Device Flows are listed and are > 0
    [Arguments]  ${logical_device_id}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl logicaldevice flows ${logical_device_id} -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True  ${length} > 0   Number of flows for ${logical_device_id} was 0

Get Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${id}=    Get From Dictionary    ${value}    id
    \    ${sn}=    Get From Dictionary    ${value}    serialnumber
    \    Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    [Return]    ${id}

Get SN From Device ID
    [Documentation]  Extracts the Serial Number (Base Number ) from Device Id
    [Arguments]     ${device_id}
    ${sn}=     Remove String    ${device_id}    -1
    [Return]  ${sn}

Validate Device Removed
    [Arguments]    ${id}
    [Documentation]    Verifys that device, ${serial_number}, has been removed
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    @{ids}=    Create List
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata}    ${INDEX}
    \    ${device_id}=    Get From Dictionary    ${value}    id
    \    Append To List    ${ids}    ${device_id}
    List Should Not Contain Value    ${ids}    ${id}