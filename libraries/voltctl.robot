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
Test Empty Device List
    [Documentation]   Verify that there are no devices in the system
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    [Return]  ${length}

Create Device
    [Arguments]    ${ip}    ${port}
    [Documentation]    Creates a device in VOLTHA
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${ip}:${port}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${device_id}

Enable Device
    [Arguments]    ${device_id}
    [Documentation]    Enables a device in VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device enable ${device_id}
    Should Be Equal As Integers    ${rc}    0

Get Device Flows from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets device flows from VOLTHA
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device flows ${device_id}
    Should Be Equal As Integers    ${rc}    0
    [Return]    ${output}

Get Logical Device Output from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets logicaldevice flows and ports from VOLTHA
    ${rc1}    ${flows}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl logicaldevice flows ${device_id}
    ${rc2}    ${ports}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl logicaldevice ports ${device_id}
    Log    ${flows}
    Log    ${ports}
    Should Be Equal As Integers    ${rc1}    0
    Should Be Equal As Integers    ${rc2}    0

Get Device Output from Voltha
    [Arguments]    ${device_id}
    [Documentation]    Gets device flows and ports from VOLTHA
    ${rc1}    ${flows}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device flows ${device_id}
    ${rc2}    ${ports}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device ports ${device_id}
    Log    ${flows}
    Log    ${ports}
    Should Be Equal As Integers    ${rc1}    0
    Should Be Equal As Integers    ${rc2}    0

Validate Device
    [Arguments]    ${admin_state}  ${oper_status}  ${connect_status}  ${serial_number}=${EMPTY}  ${device_id}=${EMPTY}
    ...    ${onu_reason}=${EMPTY}   ${onu}=False
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${serial_number} and ${device_id}
    ...    Arguments are matched for device states of: "admin_state", "oper_status", and "connect_status"
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${astate}=    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Get From Dictionary    ${value}    operstatus
        ${cstatus}=    Get From Dictionary    ${value}    connectstatus
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        ${devId}=    Get From Dictionary    ${value}    id
        ${mib_state}=    Get From Dictionary    ${value}    reason
        Run Keyword If    '${sn}' == '${serial_number}' or '${devId}' == '${device_id}'    Exit For Loop
    END
    Should Be Equal    '${astate}'    '${admin_state}'    Device ${serial_number} admin_state != ${admin_state}
    ...    values=False
    Should Be Equal    '${opstatus}'   '${oper_status}'    Device ${serial_number} oper_status != ${oper_status}
    ...    values=False
    Should Be Equal    '${cstatus}'    '${connect_status}'    Device ${serial_number} conn_status != ${connect_status}
    ...    values=False
    Run Keyword If    '${onu}' == 'True'    Should Be Equal    '${mib_state}'    '${onu_reason}'
    ...  Device ${serial_number} mib_state incorrect (${mib_state}) values=False

Validate OLT Device
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}   ${serial_number}=${EMPTY}
    ...    ${device_id}=${EMPTY}
    [Documentation]    Parses the output of "voltctl device list" and inspects device ${serial_number} and/or
    ...    ${device_id}   Match on OLT Serial number or Device Id and inspect states
    Validate Device  ${admin_state}    ${oper_status}    ${connect_status}   ${serial_number}   ${device_id}

Validate ONU Devices
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${List_ONU_Serial}
    [Documentation]    Parses the output of "voltctl device list" and inspects device  ${List_ONU_Serial}
    ...    Iteratively match on each Serial number contained in ${List_ONU_Serial} and inspect
    ...    states including MIB state
    FOR   ${serial_number}  IN  @{List_ONU_Serial}
        Validate Device    ${admin_state}    ${oper_status}    ${connect_status}    ${serial_number}
    ...    onu_reason=omci-flows-pushed    onu=True
    END

Validate Device Port Types
    [Arguments]    ${device_id}    ${pon_type}    ${ethernet_type}
    [Documentation]    Parses the output of voltctl device ports <device_id> and matches the port types listed
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device ports ${device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${astate}=    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Get From Dictionary    ${value}    operstatus
        ${type}=    Get From Dictionary    ${value}    type
        Should Be Equal    '${astate}'    'ENABLED'    Device ${device_id} port admin_state != ENABLED    values=False
        Should Be Equal    '${opstatus}'    'ACTIVE'    Device ${device_id} port oper_status != ACTIVE    values=False
        Should Be True    '${type}' == '${pon_type}' or '${type}' == '${ethernet_type}'
    ...     Device ${device_id} port type is neither ${pon_type} or ${ethernet_type}
    END

Validate OLT Port Types
    [Documentation]  Parses the output of voltctl device ports ${olt_device_id} and matches the port types listed
    [Arguments]     ${pon_type}     ${ethernet_type}
    Validate Device Port Types   ${olt_device_id}    ${pon_type}     ${ethernet_type}

Validate ONU Port Types
    [Arguments]     ${List_ONU_Serial}  ${pon_type}     ${ethernet_type}
    [Documentation]  Parses the output of voltctl device ports for each ONU SN listed in ${List_ONU_Serial}
    ...     and matches the port types listed
    FOR    ${serial_number}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${serial_number}
        Validate Device Port Types    ${onu_dev_id}    ${pon_type}     ${ethernet_type}
    END

Validate Device Flows
    [Arguments]    ${device_id}    ${test}=${EMPTY}
    [Documentation]    Parses the output of voltctl device flows <device_id> and expects flow count > 0
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device flows ${device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Log    'Number of flows = ' ${length}
    Run Keyword If    '${test}' == '${EMPTY}'    Should Be True    ${length} > 0
    ...    Number of flows for ${device_id} was 0
    ...    ELSE    Should Be True  ${length} == ${test}
    ...    Number of flows for ${device_id} was not ${test}

Validate OLT Flows
    [Documentation]    Parses the output of voltctl device flows ${olt_device_id} and expects flow count > 0
    Validate Device Flows    ${olt_device_id}

Validate ONU Flows
    [Arguments]    ${List_ONU_Serial}    ${test}
    [Documentation]    Parses the output of voltctl device flows for each ONU SN listed in ${List_ONU_Serial}
    ...    and expects flow count == 0
    FOR     ${serial_number}    IN    @{List_ONU_Serial}
        ${onu_dev_id}=    Get Device ID From SN    ${serial_number}
        Validate Device Flows    ${onu_dev_id}    ${test}
    END

Validate Logical Device
    [Documentation]    Validate Logical Device is listed
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl logicaldevice list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${devid}=    Get From Dictionary    ${value}    id
        ${rootdev}=    Get From Dictionary    ${value}    rootdeviceid
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        Exit For Loop
    END
    Should Be Equal    '${rootdev}'    '${olt_device_id}'    Root Device does not match ${olt_device_id}    values=False
    Should Be Equal    '${sn}'    '${BBSIM_OLT_SN}'    Logical Device ${sn} does not match ${BBSIM_OLT_SN}
    ...    values=False
    [Return]  ${devid}

Validate Logical Device Ports
    [Arguments]    ${logical_device_id}
    [Documentation]    Validate Logical Device Ports are listed and are > 0
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice ports ${logical_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True    ${length} > 0    Number of ports for ${logical_device_id} was 0

Validate Logical Device Flows
    [Arguments]    ${logical_device_id}
    [Documentation]    Validate Logical Device Flows are listed and are > 0
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice flows ${logical_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    Should Be True  ${length} > 0    Number of flows for ${logical_device_id} was 0

Retrieve Peer List From OLT
    [Arguments]     ${olt_peer_list}
    [Documentation]    Retrieve the list of peer device id list from port list
    ${rc}  ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device ports ${olt_device_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${peers}=    Get From Dictionary    ${value}    peers
        Run Keyword If    '${type}' == 'PON_OLT'    Exit For Loop
    END
    ${length}=    Get Length    ${peers}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${peers}    ${INDEX}
        ${peer_id}=    Get From Dictionary    ${value}    deviceid
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
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR     ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${devid}=    Get From Dictionary    ${value}    id
        Run Keyword If    '${devid}' == '${olt_peer_id}'    Exit For Loop
        Run Keyword If    '${INDEX}' == '${length}'    Fail    Peer id ${olt_peer_id} does not match any ONU device id;
    END

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
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device ports ${onu_dev_id} -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${type}=    Get From Dictionary    ${value}    type
        ${peers}=    Get From Dictionary    ${value}    peers
        Run Keyword If    '${type}' == 'PON_ONU'    Exit For Loop
    END
    ${length}=    Get Length    ${peers}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${peers}    ${INDEX}
        ${peer_id}=    Get From Dictionary    ${value}    deviceid
    END
    Should Be Equal    '${peer_id}'    '${olt_device_id}'
    ...    Mismatch between ONU peer ${peer_id} and OLT device id ${olt_device_id}    values=False

Get Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${id}=    Get From Dictionary    ${value}    id
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    END
    [Return]    ${id}

Get Logical Device ID From SN
    [Arguments]    ${serial_number}
    [Documentation]    Gets the device id by matching for ${serial_number}
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${id}=    Get From Dictionary    ${value}    parentid
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    END
    [Return]    ${id}

Build ONU SN List
    [Arguments]    ${serial_numbers}
    [Documentation]    Appends all ONU SNs to the ${serial_numbers} list
    FOR    ${INDEX}    IN RANGE    0    ${num_onus}
        Append To List    ${serial_numbers}    ${hosts.src[${INDEX}].sn}
    END

Get SN From Device ID
    [Arguments]    ${device_id}
    [Documentation]    Gets the device id by matching for ${device_id}
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${jsondata}=    To Json    ${output}
    Log    ${jsondata}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${id}=    Get From Dictionary    ${value}    id
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        Run Keyword If    '${id}' == '${device_id}'    Exit For Loop
    END
    [Return]    ${sn}

ONU Discovery
    [Documentation]    Discover lists of ONUS, their Serial Numbers and device id.
    #build onu sn list
    ${List_ONU_Serial}  Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Set Suite Variable    ${List_ONU_Serial}
    Log    BBSIM_ONU_SN=${List_ONU_Serial}

Validate Device's Ports and Flows
    [Documentation]    Verify Ports and Flows listed for OLT and ONUs
    ...    For OLT we validate the port types and numbers and for flows we simply verify that their numbers > 0
    ...    For each ONU, we validate the port types and numbers for each and for flows.
    ...    For flows they should be == 0 at this stage
    [Tags]    functional
    #validate olt port types
    Validate OLT Port Types    PON_OLT    ETHERNET_NNI
    #validate olt flows
    Validate OLT Flows
    #validate onu port types
    Validate ONU Port Types    ${List_ONU_Serial}    PON_ONU    ETHERNET_UNI
    #validate onu flows
    Validate ONU Flows    ${List_ONU_Serial}    4

Validate Logical Device Ports and Flows
    [Documentation]    Verify that logical device exists and then verify its ports and flows
    [Tags]    functional
    #Verify logical device exists
    ${logical_device_id}=    Validate Logical Device
    #Verify logical device ports
    Validate Logical Device Ports    ${logical_device_id}
    #Verify logical device flows
    Validate Logical Device Flows    ${logical_device_id}

Validate Peer Devices
    [Documentation]    Verify that peer lists matches up between that of ${olt_device_id}
    ...    and individual ONU device ids
    [Tags]    functional
    #Retrieve peer list from OLT
    ${olt_peer_list}=    Create List
    Retrieve Peer List From OLT    ${olt_peer_list}
    Log    ${olt_peer_list}
    #Validate OLT peer id list
    Validate OLT Peer Id List    ${olt_peer_list}
    #Validate ONU peer ids
    Validate ONU Peer Id    ${olt_device_id}    ${List_ONU_Serial}

Validate Device Removed
    [Arguments]    ${id}
    [Documentation]    Verifys that device, ${serial_number}, has been removed
    ${output}=    Run    ${VOLTCTL_CONFIG}; voltctl device list -o json
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
