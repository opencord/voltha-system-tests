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
${long_timeout}    420
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
    ${length}=    Test Empty Device List
    Should Be Equal As Integers  ${length}    0
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Global Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    60s    5s    Validate OLT Device   PREPROVISIONED    UNKNOWN    UNKNOWN  ${EMPTY}
    ...    ${olt_device_id}
    #enable device
    Enable Device    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    60s    5s    Validate OLT Device   ENABLED    ACTIVE    REACHABLE    ${EMPTY}
    ...    ${olt_device_id}

ONU Discovery
    [Documentation]    Discover lists of ONUS, their Serial Numbers and device id
    [Tags]    active
    #build onu sn list
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Log    ${List_ONU_Serial}
    #validate onu states
    Wait Until Keyword Succeeds    ${long_timeout}    20s    Validate ONU Devices    ENABLED    ACTIVE    REACHABLE
    ...    ${List_ONU_Serial}

Validate Device's Ports and Flows
    [Documentation]    Verify Ports and Flows listed for OLT and ONUs
    ...    For OLT we validate the port types and numbers and for flows we simply verify that their numbers > 0
    ...    For each ONU, we validate the port types and numbers for each and for flows.
    ...    For flows they should be == 0 at this stage
    [Tags]    active
    #validate olt port types
    Validate OLT Port Types    PON_OLT    ETHERNET_NNI
    #validate olt flows
    Validate OLT Flows
    #validate onu port types
    Validate ONU Port Types    ${List_ONU_Serial}    PON_ONU    ETHERNET_UNI
    #validate onu flows
    Validate ONU Flows    ${List_ONU_Serial}    ${num_onu_flows}

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
    [Documentation]    Setup the whole test suite
    # BBSim sanity test doesn't need these imports from other repositories
    Run Keyword If    ${external_libs}    Import Library
    ...    ${CURDIR}/../../../voltha/tests/atests/common/testCaseUtils.py
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/Subscriber.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/OLT.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/DHCP.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../../cord-tester/src/test/cord-api/Framework/Kubernetes.robot
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
    Check CLI Tools Configured
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${k8s_node_ip}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    ${olt_ip}=    Evaluate    ${olts}[0].get("ip")
    ${olt_user}=    Evaluate    ${olts}[0].get("user")
    ${olt_pass}=    Evaluate    ${olts}[0].get("pass")
    ${olt_serial_number}=    Evaluate    ${olts}[0].get("serial")
    ${num_onus}=    Get Length    ${hosts.src}
    ${num_onus}=    Convert to String    ${num_onus}
    #send sadis file to onos
    ${sadis_file}=    Evaluate    ${sadis}.get("file")
    Log To Console  \nSadis File:${sadis_file}
    Run Keyword Unless    '${sadis_file}' is '${None}'    Send File To Onos    ${sadis_file}    apps/
    Set Suite Variable    ${num_onus}
    Set Suite Variable    ${olt_serial_number}
    Set Suite Variable    ${olt_ip}
    Set Suite Variable    ${olt_user}
    Set Suite Variable    ${olt_pass}
    Set Suite Variable    ${k8s_node_ip}
    Set Suite Variable    ${k8s_node_user}
    Set Suite Variable    ${k8s_node_pass}
    @{container_list}=    Create List    adapter-open-olt    adapter-open-onu    voltha-api-server
    ...    voltha-ro-core    voltha-rw-core-11    voltha-rw-core-12    voltha-ofagent
    Set Suite Variable    ${container_list}
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}

Teardown Suite
    [Documentation]    Clean up devices if desired
    ...    kills processes and cleans up interfaces on src+dst servers
    Run Keyword If    ${external_libs}    Get ONOS Status    ${k8s_node_ip}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${external_libs}    Log Kubernetes Containers Logs Since Time    ${datetime}    ${container_list}
    Run Keyword If    ${teardown_device}    Delete Device and Verify
    ${length}=    Run Keyword If    ${teardown_device}    Run Keyword And Return    Test Empty Device List
    Run Keyword If    ${teardown_device}    Should Be Equal As Integers    ${length}    0
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