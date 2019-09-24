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
Library           HttpLibrary.HTTP
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Execute ONOS CLI Command
    [Arguments]    ${host}    ${port}    ${cmd}
    [Documentation]    Establishes an ssh connection to the onos contoller and executes a command
    ${conn_id}=    SSHLibrary.Open Connection    ${host}    port=${port}    prompt=onos>    timeout=300s
    SSHLibrary.Login    karaf    karaf
    ${output}=    SSHLibrary.Execute Command    ${cmd}
    Log    ${output}
    SSHLibrary.Close Connection
    [Return]    ${output}

Validate OLT Device in ONOS
#    FIXME use volt-olts to check that the OLT is ONOS
    [Documentation]    Checks if olt has been connected to ONOS
    [Arguments]    ${serial_number}
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    @{serial_numbers}=    Create List
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
    \    ${of_id}=    Get From Dictionary    ${value}    id
    \    ${sn}=    Get From Dictionary    ${value}    serial
    \    Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    Should Be Equal As Strings    ${sn}    ${serial_number}
    [Return]    ${of_id}

Get ONU Port in ONOS
    [Documentation]    Retrieves ONU port for the ONU in ONOS
    [Arguments]    ${onu_serial_number}   ${olt_of_id}
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
    \    ${annotations}=    Get From Dictionary    ${value}    annotations
    \    ${onu_port}=    Get From Dictionary    ${value}    port
    \    ${portName}=    Get From Dictionary    ${annotations}    portName
    \    Run Keyword If    '${portName}' == '${onu_serial_number}'    Exit For Loop
    Should Be Equal As Strings    ${portName}    ${onu_serial_number}
    [Return]    ${onu_port}

Verify Eapol Flows Added
    [Arguments]    ${ip}    ${port}    ${expected_flows}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}    flows -s -f ADDED | grep eapol | grep IN_PORT | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_flows}

Verify Number of AAA-Users
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ##TODO: filter by onu serial number instead of count
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | wc -l
    Should Contain    ${aaa_users}    ${expected_onus}

Validate DHCP Allocations
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of dhcpacks based on number of onus
    ##TODO: filter by onu serial number instead of count
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}    dhcpl2relay-allocations | grep DHCPACK | wc -l
    Should Contain    ${allocations}    ${expected_onus}
