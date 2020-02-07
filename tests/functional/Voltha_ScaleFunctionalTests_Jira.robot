#Copyright 2017-present Open Networking Foundation
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
Documentation    Test suite that engages a larger number of ONU at the same which makes it a more realistic test
...    It is addaptable to either BBSim or Real H/W using a configuration file
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite
Library           Collections
Library           String
Library           OperatingSystem
Library           XML
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot

*** Variables ***
${timeout}         60s
${long_timeout}	420
${of_id}           0
${logical_id}      0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    False

*** Test Cases ***
Activate Devices OLT/ONU
    [Documentation]    Validate deployment -> Empty Device List
    ...    create and enable device -> Preprovision and Enable
    ...    re-validate deployment -> Active OLT
    [Tags]    active
    #test for empty device list
    Test Empty Device List
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Global Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device   PREPROVISIONED    UNKNOWN    UNKNOWN
    ...	${EMPTY}
    ...    ${olt_device_id}
    #enable device
    Enable Device    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device   ENABLED    ACTIVE    REACHABLE    ${EMPTY}
    ...    ${olt_device_id}

ONU Discovery
    [Documentation]    Discover lists of ONUS, their Serial Numbers and device id
    [Tags]    active
    #build onu sn list
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    #validate onu states
    Wait Until Keyword Succeeds    ${long_timeout}    20s    Validate ONU Devices    ENABLED    ACTIVE    REACHABLE
    ...    ${List_ONU_Serial}

Verify AAA-Users Authentication
    [Documentation]    Authenticating all AAA-users in onos
    [Tags]    VOL-1823
    #build onu sn list
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Wait Until Keyword Succeeds    ${long_timeout}    60s	Verify Number of AAA-Users	${k8s_node_ip}	${ONOS_SSH_PORT}	16

Validate Device's Ports and Flows
    [Documentation]    Verify Ports and Flows listed for OLT and ONUs
    ...    For OLT we validate the port types and numbers and for flows we simply verify that their numbers > 0
    ...    For each ONU, we validate the port types and numbers for each and for flows.
    ...    For flows they should be == 0 at this stage
    [Tags]    active
    #validate olt port types
    Validate OLT Port Types    PON_OLT    ETHERNET_NNI
    #validate olt flows
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows
    #validate onu port types
    Validate ONU Port Types    ${List_ONU_Serial}    PON_ONU    ETHERNET_UNI
    #validate onu flows
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONU Flows    ${List_ONU_Serial}    ${num_onu_flows}

Verify Total Number Of Eapol Flows
    [Documentation]    Verify Flows listed for ONUs
    ...    For 16 ONUs we validate the number of flows to be 16 eapol flows
    [Tags]    VOL-1823
    #verify eapol flows added
    Wait Until Keyword Succeeds    ${long_timeout}    5s    Verify Eapol Flows Added	${k8s_node_ip}	${ONOS_SSH_PORT}	16

Allocate DHCP To All ONU Devices
    [Documentation]  DHCP Allocation for all ONUs
    [Tags]  VOL-1824
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
	${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds	${timeout}    2s
        ...	Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...	Execute ONOS CLI Command	${k8s_node_ip}    ${ONOS_SSH_PORT}	volt-add-subscriber-access ${of_id} ${onu_port}
    END

Validate Total Number Of DHCP Allocations
    [Documentation]  Verify dhcp allocation for multiple ONU user
    [Tags]  VOL-1824
    #validate total number of DHCP allocations
    Wait Until Keyword Succeeds  ${long_timeout}  20s  Validate DHCP Allocations  ${k8s_node_ip}
    ...	${ONOS_SSH_PORT}        16
    #validate DHCP allocation for each port
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds	${timeout}    2s
	...	Get ONU Port in ONOS    ${src['onu']}    ${of_id}
	Wait Until Keyword Succeeds  ${long_timeout}  20s  Validate Subscriber DHCP Allocation	${k8s_node_ip}
	...	${ONOS_SSH_PORT}	${onu_port}
    END

Validate Logical Device
    [Documentation]    Verify that logical device exists and then verify its ports and flows
    [Tags]    active
    #Verify logical device exists
    ${logical_device_id}=    Validate Logical Device
    #Verify logical device ports
    Validate Logical Device Ports    ${logical_device_id}
    #Verify logical device flows
    Validate Logical Device Flows    ${logical_device_id}

Validate Peer Devices
    [Documentation]    Verify that peer lists matches up between that of ${olt_device_id}
    ...    and individual ONU device ids
    [Tags]    active
    #Retrieve peer list from OLT
    ${olt_peer_list}=    Create List
    Retrieve Peer List From OLT    ${olt_peer_list}
    Log    ${olt_peer_list}
    #Validate OLT peer id list
    Validate OLT Peer Id List    ${olt_peer_list}
    #Validate ONU peer ids
    Validate ONU Peer Id    ${olt_device_id}    ${List_ONU_Serial}

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup

Teardown Suite
    [Documentation]    Clean up devices if desired
    ...    kills processes and cleans up interfaces on src+dst servers
    Run Keyword If    ${external_libs}    Get ONOS Status    ${k8s_node_ip}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${external_libs}    Log Kubernetes Containers Logs Since Time    ${datetime}    ${container_list}
    Run Keyword If    ${teardown_device}    Delete Device and Verify
    Run Keyword If    ${teardown_device}    Test Empty Device List
    Run Keyword If    ${teardown_device}    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
    ...    device-remove ${of_id}

Clean Up Linux
    [Documentation]    Kill processes and clean up interfaces on src+dst servers
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword And Ignore Error    Kill Linux Process    [w]pa_supplicant    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Ignore Error    Kill Linux Process    [d]hclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Run Keyword And Ignore Error
        ...    Kill Linux Process    [d]hcpd    ${dst['ip']}    ${dst['user']}
        ...    ${dst['pass']}    ${dst['container_type']}    ${dst['container_name']}
        Delete IP Addresses from Interface on Remote Host    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Delete Interface on Remote Host
        ...    ${dst['dp_iface_name']}.${src['s_tag']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}
        ...    ${dst['container_type']}    ${dst['container_name']}
    END

Delete Device and Verify
    [Documentation]    Disable -> Delete devices via voltctl and verify its removed
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
    ...    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed    ${olt_device_id}
