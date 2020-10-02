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
# robot test functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Library           CORDRobot
Library           ImportResource    resources=CORDRobot

*** Keywords ***
Check CLI Tools Configured
    [Documentation]    Tests that use 'voltctl' and 'kubectl' should execute this keyword in suite setup
    # check voltctl and kubectl configured
    ${voltctl_rc}=    Run And Return RC    voltctl device list
    ${kubectl_rc}=    Run And Return RC    kubectl get pods
    Run Keyword If    ${voltctl_rc} != 0 or ${kubectl_rc} != 0    FATAL ERROR
    ...    VOLTCTL and KUBECTL not configured. Please configure before executing tests.

Send File To Onos
    [Documentation]    Send the content of the file to Onos to selected section of configuration
    ...   using Post Request
    [Arguments]    ${CONFIG_FILE}    ${section}
    ${Headers}=    Create Dictionary    Content-Type    application/json
    ${File_Data}=    OperatingSystem.Get File    ${CONFIG_FILE}
    Log    ${Headers}
    Log    ${File_Data}
    ${resp}=    Post Request    ONOS
    ...    /onos/v1/network/configuration/${section}    headers=${Headers}    data=${File_Data}
    Should Be Equal As Strings    ${resp.status_code}    200

Common Test Suite Setup
    [Documentation]    Setup the test suite
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${ONOS_REST_IP}=    Get Environment Variable    ONOS_REST_IP    ${k8s_node_ip}
    ${ONOS_SSH_IP}=     Get Environment Variable    ONOS_SSH_IP     ${k8s_node_ip}
    Set Global Variable    ${ONOS_REST_IP}
    Set Global Variable    ${ONOS_SSH_IP}
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
    Check CLI Tools Configured
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${ONOS_REST_IP}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    ${olt_ip}=    Evaluate    ${olts}[0].get("ip")
    ${olt_ssh_ip}=    Evaluate    ${olts}[0].get("sship")
    ${olt_user}=    Evaluate    ${olts}[0].get("user")
    ${olt_pass}=    Evaluate    ${olts}[0].get("pass")
    ${olt_serial_number}=    Evaluate    ${olts}[0].get("serial")
    ${num_onus}=    Get Length    ${hosts.src}
    ${num_onus}=    Convert to String    ${num_onus}
    #send sadis file to onos
    ${sadis_file}=    Get Variable Value    ${sadis.file}
    Log To Console    \nSadis File:${sadis_file}
    Run Keyword Unless    '${sadis_file}' is '${None}'    Send File To Onos    ${sadis_file}    apps/
    Set Suite Variable    ${num_onus}
    Set Suite Variable    ${olt_serial_number}
    Set Suite Variable    ${olt_ip}
    Set Suite Variable    ${olt_ssh_ip}
    Set Suite Variable    ${olt_user}
    Set Suite Variable    ${olt_pass}
    @{container_list}=    Create List    adapter-open-olt    adapter-open-onu    voltha-api-server
    ...    voltha-ro-core    voltha-rw-core-11    voltha-rw-core-12    voltha-ofagent
    Set Suite Variable    ${container_list}
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}

WPA Reassociate
    [Documentation]    Executes a particular wpa_cli reassociate, which performs force reassociation
    [Arguments]    ${iface}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    #Below for loops are used instead of sleep time, to execute reassociate command and check status
    FOR    ${i}    IN RANGE    70
        ${output}=    Login And Run Command On Remote System
        ...    wpa_cli -i ${iface} reassociate    ${ip}    ${user}
        ...    ${pass}    ${container_type}    ${container_name}
        ${passed}=    Run Keyword And Return Status    Should Contain    ${output}    OK
        Exit For Loop If    ${passed}
    END
    Should Be True    ${passed}    Status does not contain 'SUCCESS'
    FOR    ${i}    IN RANGE    70
        ${output}=    Login And Run Command On Remote System
        ...    wpa_cli -i ${iface} status | grep SUCCESS    ${ip}    ${user}
        ...    ${pass}    ${container_type}    ${container_name}
        ${passed}=    Run Keyword And Return Status    Should Contain    ${output}    SUCCESS
        Exit For Loop If    ${passed}
    END
    Should Be True    ${passed}    Status does not contain 'SUCCESS'

Validate Authentication After Reassociate
    [Arguments]    ${auth_pass}    ${iface}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]
    ...    Executes a particular reassociate request on the RG using wpa_cli.
    ...    auth_pass determines if authentication should pass
    ${wpa_log}=    Catenate    SEPARATOR=.    /tmp/wpa    ${iface}    log
    ${output}=    Login And Run Command On Remote System    truncate -s 0 ${wpa_log}; cat ${wpa_log}
    ...    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Log    ${output}
    Should Not Contain    ${output}    authentication completed successfully
    WPA Reassociate    ${iface}    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'True'    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Remote File Contents    True    ${wpa_log}    ${iface}.*authentication completed successfully
    ...    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'False'    Sleep    20s
    Run Keyword If    '${auth_pass}' == 'False'    Check Remote File Contents    False    /tmp/wpa.log
    ...    ${iface}.*authentication completed successfully    ${ip}    ${user}    ${pass}
    ...    ${container_type}    ${container_name}

Send Dhclient Request To Release Assigned IP
    [Arguments]    ${iface}    ${ip}    ${user}    ${path_dhcpleasefile}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]    Executes a dhclient with option to release ip against a particular interface on the RG (src)
    ${result}=    Login And Run Command On Remote System
    ...    dhclient -nw -r ${iface} && rm ${path_dhcpleasefile}/dhclient.*    ${ip}    ${user}
    ...    ${pass}    ${container_type}    ${container_name}
    Log    ${result}
    #Should Contain    ${result}    DHCPRELEASE
    [Return]    ${result}

Check Remote File Contents For WPA Logs
    [Arguments]    ${file_should_exist}    ${file}    ${pattern}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}    ${prompt}=~$
    [Documentation]    Checks for particular pattern count in a file
    ${result}=    Login And Run Command On Remote System
    ...    cat ${file} | grep '${pattern}' | wc -l    ${ip}    ${user}    ${pass}
    ...    ${container_type}    ${container_name}    ${prompt}
    [Return]    ${result}

Perform Sanity Test
    [Documentation]    This keyword performs Sanity Test Procedure
    ...    Sanity test performs authentication, dhcp and pings for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Get NNI Port in ONOS    ${of_id}
    Set Global Variable    ${nni_port}
    # Verify Default Meter in ONOS (valid only for ATT)
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Default Meter Present in ONOS    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword and Ignore Error    Collect Logs
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Perform Authentication
        ${wpa_log}=    Run Keyword If    ${has_dataplane}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify that no pending flows exist for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
        # Verify Meters in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Meters in ONOS    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

Perform Sanity Test DT
    [Documentation]    This keyword performs Sanity Test Procedure for DT Workflow
    ...    Sanity test performs dhcp and pings (without EAPOL and DHCP flows) for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.
    ${of_id}=    Wait Until Keyword Succeeds    360s    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Get NNI Port in ONOS    ${of_id}
    Set Global Variable    ${nni_port}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify Meters in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Meters in ONOS    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}    ${onu_port}
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END
    # Verify ONOS Flows
    # Number of Access Flows on ONOS equals 4 * the Number of Active ONUs (2 for each downstream and upstream)
    ${onos_flows_count}=    Evaluate    4 * ${num_onus}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Verify Subscriber Access Flows Added Count DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    ...    ${onos_flows_count}
    # Verify VOLTHA Flows
    # Number of per OLT Flows equals Twice the Number of Active ONUs (each for downstream and upstream) + 1 for LLDP
    ${olt_flows}=    Evaluate    2 * ${num_onus} + 1
    # Number of per ONU Flows equals 2 (one each for downstream and upstream)
    ${onu_flows}=    Set Variable    2
    Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows    ${olt_flows}
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Log    ${List_ONU_Serial}
    Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONU Flows
    ...    ${List_ONU_Serial}    ${onu_flows}

Perform Sanity Test TT
    [Documentation]    This keyword performs Sanity Test Procedure for TT Workflow
    ...    Sanity test performs dhcp and pings (without EAPOL and DHCP flows) for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${service_type}=    Get Variable Value    ${src['service_type']}    "null"
        Run Keyword IF    '${service_type}' != 'mcast'    Sanity Test TT one ONU    ${src}    ${dst}
        Run Keyword and Ignore Error    Collect Logs
    END
    Run Keyword and Ignore Error    Collect Logs

Sanity Test TT one ONU
    [Documentation]    This keyword performs sanity test for a single ONU for TT workflow
    ...       Tests for one ONU
    ...       Assertions apply to HSIA, VoD, VoIP services
    [Arguments]    ${src}    ${dst}
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Get NNI Port in ONOS    ${of_id}
    Set Global Variable    ${nni_port}
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
    # Check ONU port is Enabled in ONOS
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
    ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
    ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    volt-add-subscriber-access ${of_id} ${onu_port}
    Sleep    30s
    # Verify ONU state in voltha
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
    ...    ENABLED    ACTIVE    REACHABLE
    ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
    # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
    ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
    ...    ${dst['container_name']}
    Run Keyword IF    ${src['service_type']} != 'hsia'    and    ${src['service_type']} != 'null'
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
    ...    ${src['c_tag']}
    Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
    Run Keyword and Ignore Error    Collect Logs

Perform Sanity Test TT MCAST
    [Documentation]    This keyword performs Sanity Test Procedure for TT Workflow
    ...    Adds subscribers
    ...    Validates  for MCAST
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${service_type}=    Get Variable Value    ${src['service_type']}    "null"
        Run Keyword IF    '${service_type}' == 'mcast'    Sanity Test TT MCAST one ONU    ${src}
        ...    ${dst}
        Run Keyword and Ignore Error    Collect Logs
    END
    Run Keyword and Ignore Error    Collect Logs

Sanity Test TT MCAST one ONU
    [Documentation]    This keyword performs sanity test for a single ONU for TT workflow
    ...       Tests for one ONU
    ...       Assertions apply to MCAST services
    [Arguments]    ${src}    ${dst}
    # Check for iperf and jq tools
    ${stdout}    ${stderr}    ${rc}=    Execute Remote Command    which iperf jq
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
    ...    ${src['container_name']}
    Pass Execution If    ${rc} != 0    Skipping test: iperf / jq not found on the RG

    #Reset the IP on the interface
    ${output}=    Login And Run Command On Remote System    sudo ifconfig ${src['dp_iface_name']} 0
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    # Kill iperf  on BNG
    ${rg_output}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf`
    ...    ${dst['bng_ip']}    ${dst['bng_user']}    ${dst['bng_pass']}    ${dst['container_type']}
    ...    ${dst['container_name']}

    # Setup RG for Multi-cast test
    ${output}=    Login And Run Command On Remote System
    ...    sudo ifconfig ${src['dp_iface_name']} ${src['mcast_rg']} up ; sudo kill -9 `pidof iperf`
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    ${output}=    Login And Run Command On Remote System
    ...    sudo ip route add ${src['mcast_grp_subnet_mask']} dev ${src['dp_iface_name']} scope link
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}

    # Perform operations for adding subscriber
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Get NNI Port in ONOS    ${of_id}
    Set Global Variable    ${nni_port}
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
    # Check ONU port is Enabled in ONOS
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
    ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
    ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    volt-add-subscriber-access ${of_id} ${onu_port}
    Sleep    30s
    # Verify ONU state in voltha
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
    ...    ENABLED    ACTIVE    REACHABLE
    ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed

    # Setup iperf on the BNG
    ${server_output}=    Login And Run Command On Remote System
    ...    sudo iperf -c ${dst['dp_iface_ip_qinq']} -u -T 32 -t 60 -i 1 &
    ...    ${dst['bng_ip']}    ${dst['bng_user']}    ${dst['bng_pass']}    ${dst['container_type']}
    ...    ${dst['container_name']}

    # Setup iperf on the RG
    ${rg_output}=    Run Keyword and Continue On Failure    Wait Until Keyword Succeeds     90s    5s
    ...    Login And Run Command On Remote System
    ...    rm -rf /tmp/rg_output ; sudo iperf -s -u -B ${dst['dp_iface_ip_qinq']} -i 1 -D >> /tmp/rg_output
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Log    ${rg_output}
    Sleep    60s
    ${output}=    Run Keyword and Continue On Failure     Wait Until Keyword Succeeds     90s    5s
    ...    Login And Run Command On Remote System
    ...    cat /tmp/rg_output | grep KBytes
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Log    ${output}
    Should Contain    ${output}    KBytes

    # Kill iperf  on BNG
    ${rg_output}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf`
    ...    ${dst['bng_ip']}    ${dst['bng_user']}    ${dst['bng_pass']}    ${dst['container_type']}
    ...    ${dst['container_name']}

    # Kill iperf on the RG
    ${output}=    Run Keyword and Continue On Failure    Login And Run Command On Remote System
    ...    sudo kill -9 `pidof iperf`
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}


Setup
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    #Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    #...    ${olt_ip}    ${olt_user}    ${olt_pass}
    Run Keyword If    ${has_dataplane}    Sleep    230s
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}
    Sleep    5s
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    380s    5s
    ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}

Validate ONUs After OLT Disable
    [Documentation]    Validates the ONUs state in Voltha, ONUs port state in ONOS
    ...    and that pings do not succeed After corresponding OLT is Disabled
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=True    onu_reason=stopping-openomci
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

Delete All Devices and Verify
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Clear devices from VOLTHA
    Disable Devices In Voltha    Root=true
    Sleep    5s
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Devices Disabled In Voltha    Root=true
    Delete Devices In Voltha    Root=true
    Run Keyword If    ${has_dataplane}    Sleep    30s
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Empty Device List
    # Clear devices from ONOS
    #Remove All Devices From ONOS
    #...    http://karaf:karaf@${ONOS_REST_IP}:${ONOS_REST_PORT}

Teardown
    [Documentation]    kills processes and cleans up interfaces on src+dst servers
    Run Keyword If    ${has_dataplane}    Clean Up Linux

Teardown Suite
    [Documentation]    Clean up device if desired
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify

Delete Device and Verify
    [Documentation]    Disable -> Delete devices via voltctl and verify its removed
    ${olt_device_id}=    Get Device ID From SN    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Sleep    5s
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Run Keyword If    ${has_dataplane}    Sleep    50s
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed    ${olt_device_id}

Repeat Sanity Test
    [Documentation]    This keyword performs Sanity Test Procedure
    ...    Sanity test performs authentication, dhcp and pings for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    with wpa reassociation
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        Run Keyword and Ignore Error    Collect Logs
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOD
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Perform Authentication
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate Authentication After Reassociate
        ...    True    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}     ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate DHCP and Ping    True    True
        ...    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error   Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error   Collect Logs
    END

Validate ONUs for PON OLT Disable
    [Arguments]    ${olt_peer_list}
    [Documentation]     This keyword validates that Ping fails for ONUs connected to Disabled OLT PON port
    ...    And Pings succeed for other Active OLT PON port ONUs
    ...    Also it removes subscriber for Disabled OLT PON port ONUs to replicate ATT workflow
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${matched}=    Match ONU in PON OLT Peer List    ${olt_peer_list}    ${onu_device_id}
        Run Keyword If    ${matched}
        ...    Run Keywords
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=True    onu_reason=stopping-openomci
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        ...    AND    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
        # Remove Subscriber Access (To replicate ATT workflow)
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        ...    ELSE
        ...    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
        Run Keyword and Ignore Error    Collect Logs
    END

Validate ONUs for PON OLT Enable
    [Arguments]    ${olt_peer_list}
    [Documentation]    This keyword validates Ping succeeds for all Enabled/Acitve OLT PON ports
    ...    Also performs Auth/subscriberAdd/DHCP/Ping for the ONUs on Re-Enabled OLT PON port
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${matched}=    Match ONU in PON OLT Peer List    ${olt_peer_list}    ${onu_device_id}
        ${wpa_log}=    Run Keyword If    ${has_dataplane} and ${matched}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${matched}
        ...    Run Keywords
        # Perform Cleanup
        ...    Run Keyword If    ${has_dataplane}    Clean Up Linux    ${onu_device_id}
        # Verify ONU port status
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        # Verify EAPOL flows are added for the ONU port
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Perform Authentication
        ...    AND    Run Keyword If    ${has_dataplane}
        ...    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify that no pending flows exist for the ONU port
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
        ...    AND    Run Keyword If    ${has_dataplane}
        ...    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}
        ...    ${dst['container_type']}    ${dst['container_name']}
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        ...    AND    Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        ...    ELSE
        ...    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
        Run Keyword and Ignore Error    Collect Logs
    END

Validate ONUs for PON OLT Disable DT
    [Arguments]    ${olt_peer_list}
    [Documentation]     This keyword validates that Ping fails for ONUs connected to Disabled OLT PON port
    ...    And Pings succeed for other Active OLT PON port ONUs
    ...    Also it removes subscriber and deletes ONUs for Disabled OLT PON port to replicate DT workflow
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${matched}=    Match ONU in PON OLT Peer List    ${olt_peer_list}    ${onu_device_id}
        Run Keyword If    ${matched}
        ...    Run Keywords
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=True    onu_reason=stopping-openomci
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify ONU Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        ...    AND    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
        # Remove Subscriber Access (To replicate DT workflow)
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Execute ONOS CLI Command    ${ONOS_SSH_IP}
        ...    ${ONOS_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        ...    AND    Sleep    10s
        # Delete ONU Device (To replicate DT workflow)
        ...    AND    Delete Device    ${onu_device_id}
        ...    AND    Sleep    5s
        ...    ELSE
        ...    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
        Run Keyword and Ignore Error    Collect Logs
    END

Validate ONUs for PON OLT Enable DT
    [Arguments]    ${olt_peer_list}
    [Documentation]    This keyword validates Ping succeeds for all Enabled/Acitve OLT PON ports
    ...    Also performs subscriberAdd/DHCP/Ping for the ONUs on Re-Enabled OLT PON port
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${matched}=    Match ONU in PON OLT Peer List    ${olt_peer_list}    ${onu_device_id}
        Run Keyword If    ${matched}
        ...    Run Keywords
        # Perform Cleanup
        ...    Run Keyword If    ${has_dataplane}    Clean Up Linux    ${onu_device_id}
        # Verify ONU port status
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify ONU state in voltha
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify subscriber access flows are added for the ONU port
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        ...    AND    Run Keyword If    ${has_dataplane}
        ...    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}
        ...    ${dst['container_type']}    ${dst['container_name']}
        ...    ELSE
        ...    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
        Run Keyword and Ignore Error    Collect Logs
    END

Match ONU in PON OLT Peer List
    [Arguments]    ${olt_peer_list}    ${onu_device_id}
    [Documentation]     This keyword matches if ONU device is present in OLT PON port peer list
    ${matched}=    Set Variable    False
    FOR    ${olt_peer}    IN    @{olt_peer_list}
        ${matched}=    Set Variable If    '${onu_device_id}' == '${olt_peer}'    True    False
        Exit For Loop If    ${matched}
    END
    [Return]    ${matched}

Collect Logs
    [Documentation]    Collect Logs from voltha and onos cli for various commands
    Run Keyword and Ignore Error    Get Device List from Voltha
    Run Keyword and Ignore Error    Get Device Output from Voltha    ${olt_device_id}
    Run Keyword and Ignore Error    Get Logical Device Output from Voltha    ${logical_id}
    Get ONOS Status    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}

Verify ping is succesful except for given device
    [Arguments]    ${num_onus}    ${exceptional_onu_id}
    [Documentation]    Checks that ping for all the devices are successful except the given ONU.
    ${pingStatus}     Set Variable    True
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${pingStatus}     Run Keyword If    '${onu_device_id}' == '${exceptional_onu_id}'    Set Variable     False
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    ${pingStatus}    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}   ${src['container_type']}    ${src['container_name']}
    END

Echo Message to OLT Logs
    [Arguments]    ${message}
    [Documentation]     Echoes ${message} into the OLT logs
    Wait Until Keyword Succeeds    180s    10s    Execute Remote Command
    ...    printf '%s\n' '' '' '${message}' '' >> /var/log/openolt.log
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
    Wait Until Keyword Succeeds    180s    10s    Execute Remote Command
    ...    printf '%s\n' '' '' '${message}' '' >> /var/log/dev_mgmt_daemon.log
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
    Wait Until Keyword Succeeds    180s    10s    Execute Remote Command
    ...    printf '%s\n' '' '' '${message}' '' >> /var/log/openolt_process_watchdog.log
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}

Start Logging
    [Arguments]    ${label}
    [Documentation]    Start logging for test ${label}
    ${kail_process}=     Run Keyword If    "${container_log_dir}" != "${None}"   Start Process    kail    -n    default
    ...    -n    voltha    cwd=${container_log_dir}   stdout=${label}-combined.log
    Set Test Variable    ${kail_process}
    Run Keyword If    ${has_dataplane}    Echo Message to OLT Logs     START ${label}

Stop Logging
    [Arguments]    ${label}
    [Documentation]    End logging for test; remove logfile if test passed
    Run    sync
    Run Keyword If    ${kail_process}    Terminate Process    ${kail_process}
    ${test_logfile}=    Run Keyword If    "${container_log_dir}" != "${None}"
    ...    Join Path    ${container_log_dir}    ${label}-combined.log
    Run Keyword If Test Passed    Run Keyword If    "${test_logfile}" != "${None}"    Remove File    ${test_logfile}
    Run Keyword If    ${has_dataplane}    Echo Message to OLT Logs     END ${label}

Clean Up Linux
    [Documentation]    Kill processes and clean up interfaces on src+dst servers
    [Arguments]    ${onu_id}=${EMPTY}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Continue For Loop If    '${onu_id}' != '${EMPTY}' and '${onu_id}' != '${onu_device_id}'
        Execute Remote Command    sudo pkill wpa_supplicant    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Execute Remote Command    sudo pkill dhclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Execute Remote Command    sudo pkill mausezahn    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Execute Remote Command    pkill dhcpd
        ...    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}    ${dst['container_name']}
        Delete IP Addresses from Interface on Remote Host    ${src['dp_iface_name']}    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    '${dst['ip']}' != '${None}'    Delete Interface on Remote Host
        ...    ${dst['dp_iface_name']}.${src['s_tag']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}
        ...    ${dst['container_type']}    ${dst['container_name']}
        ${bng_ip}=    Get Variable Value    ${dst['noroot_ip']}
        ${bng_user}=    Get Variable Value    ${dst['noroot_user']}
        ${bng_pass}=    Get Variable Value    ${dst['noroot_pass']}
        Run Keyword If    "${bng_ip}" != "${NONE}" and "${bng_user}" != "${NONE}" and "${bng_pass}" != "${NONE}"
        ...    Execute Remote Command    sudo pkill mausezahn    ${bng_ip}    ${bng_user}    ${bng_pass}
        ...    ${dst['container_type']}    ${dst['container_name']}
    END

Clean dhclient
    [Documentation]    Kills dhclient processes only for all RGs
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Execute Remote Command    sudo pkill dhclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

Clean WPA Process
    [Documentation]    Kills wpa_supplicant processes only for all RGs
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword And Ignore Error    Kill Linux Process    [w]pa_supplicant    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

Should Be Larger Than
    [Documentation]    Verify that value_1 is > value_2
    [Arguments]    ${value_1}    ${value_2}
    Run Keyword If    ${value_1} <= ${value_2}
    ...    Fail    The value ${value_1} is not larger than ${value_2}

Should Be Larger Than Or Equal To
    [Documentation]    Verify that value_1 is >= value_2
    [Arguments]    ${value_1}    ${value_2}
    Run Keyword If    ${value_1} < ${value_2}
    ...    Fail    The value ${value_1} is not larger than or equal to ${value_2}

Should Be Float
    [Documentation]    Verify that value is a floating point number type
    [Arguments]    ${value}
    ${type}    Evaluate    type(${value}).__name__
    Should Be Equal    ${type}    float

Should Be Newer Than Or Equal To
    [Documentation]    Compare two RFC3339 dates
    [Arguments]    ${value_1}    ${value_2}
    ${unix_v1}    Parse RFC3339    ${value_1}
    ${unix_v2}    Parse RFC3339    ${value_2}
    Run Keyword If    ${unix_v1} < ${unix_v2}
    ...    Fail    The value ${value_1} is not newer than or equal to ${value_2}

Get Current Time
    [Documentation]    Return the current time in RFC3339 format
    ${output}=    Run    date -u +"%FT%T%:z"
    [return]     ${output}

Parse RFC3339
    [Documentation]     Parse an RFC3339 timestamp
    [Arguments]    ${dateStr}
    ${rc}    ${output}=    Run and Return Rc and Output     date --date="${dateStr}" "+%s"
    Should Be Equal As Numbers    ${rc}    0
    [return]    ${output}

Get Bandwidth Profile Name For Given Subscriber
    [Arguments]    ${subscriber_id}   ${stream_type}=upstreamBandwidthProfile
    [Documentation]    Keyword to get the bandwidth details of the given subscriber
    ${bandwidth_profile_output}=    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    volt-programmed-subscribers | grep ${subscriber_id}
    @{bandwidth_profile_array}=    Split String    ${bandwidth_profile_output}    ,
    Log    ${bandwidth_profile_array}
    FOR    ${value}    IN    @{bandwidth_profile_array}
        @{row_value}=    Split String    ${value}    =
        ${bandwidth_profile_name}=    Set Variable If    '${row_value[0]}' == ' ${stream_type}'
        ...    ${row_value[1]}
        ${bandwidth_profile_name}=    Convert To String    ${bandwidth_profile_name}
        Run Keyword If    "${bandwidth_profile_name}" != "None"    Exit For Loop
    END
    Log    ${bandwidth_profile_name}
    [Return]    ${bandwidth_profile_name}

Execute Remote Command
    [Documentation]    SSH into a remote host and execute a command on the bare host or in a container.
    ...    This replaces and simplifies the Login And Run Command On Remote System keyword in CORDRobot.
    [Arguments]    ${cmd}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}    ${timeout}=${None}
    ${conn_id}=    SSHLibrary.Open Connection    ${ip}
    Run Keyword If    '${pass}' != '${None}'
    ...    SSHLibrary.Login    ${user}    ${pass}
    ...    ELSE
    ...    SSHLibrary.Login With Public Key    ${user}    %{HOME}/.ssh/id_rsa
    ${namespace}=    Run Keyword If    '${container_type}' == 'K8S'    SSHLibrary.Execute Command
    ...    kubectl get pods --all-namespaces | grep ${container_name} | awk '{print $1}'
    ${stdout}    ${stderr}    ${rc}=    Run Keyword If    '${container_type}' == 'LXC'
    ...        SSHLibrary.Execute Command    lxc exec ${container_name} -- ${cmd}
    ...        return_stderr=True    return_rc=True    timeout=${timeout}
    ...    ELSE IF    '${container_type}' == 'K8S'
    ...        SSHLibrary.Execute Command    kubectl -n ${namespace} exec ${container_name} -- ${cmd}
    ...        return_stderr=True    return_rc=True    timeout=${timeout}
    ...    ELSE
    ...        SSHLibrary.Execute Command    ${cmd}    return_stderr=True    return_rc=True    timeout=${timeout}

    Log    ${stdout}
    Log    ${stderr}
    Log    ${rc}
    SSHLibrary.Close Connection
    [Return]    ${stdout}    ${stderr}    ${rc}

Start Remote Command
    [Documentation]    SSH into a remote host and execute a command on the bare host or in a container.
    ...    This replaces and simplifies the Login And Run Command On Remote System keyword in CORDRobot.
    [Arguments]    ${cmd}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    ${conn_id}=    SSHLibrary.Open Connection    ${ip}
    Run Keyword If    '${pass}' != '${None}'
    ...    SSHLibrary.Login    ${user}    ${pass}
    ...    ELSE
    ...    SSHLibrary.Login With Public Key    ${user}    %{HOME}/.ssh/id_rsa
    ${namespace}=    Run Keyword If    '${container_type}' == 'K8S'    SSHLibrary.Execute Command
    ...    kubectl get pods --all-namespaces | grep ${container_name} | awk '{print $1}'
    Run Keyword If    '${container_type}' == 'LXC'
    ...        SSHLibrary.Start Command    lxc exec ${container_name} -- ${cmd}
    ...    ELSE IF    '${container_type}' == 'K8S'
    ...        SSHLibrary.Start Command    kubectl -n ${namespace} exec ${container_name} -- ${cmd}
    ...    ELSE
    ...        SSHLibrary.Start Command    ${cmd}
    # It seems that closing the connection immediately will sometimes kill the command
    Sleep    1s
    SSHLibrary.Close Connection

Run Iperf3 Test Client
    [Arguments]    ${src}    ${server}    ${args}
    [Documentation]    Login to ${src} and run the iperf3 client against ${server} using ${args}.
    ...    Return a Dictionary containing the results of the test.
    ${output}    ${stderr}    ${rc}=    Execute Remote Command    iperf3 -J -c ${server} ${args} | jq -M -c '.'
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Should Be Equal As Integers    ${rc}    0
    ${object}=    Evaluate    json.loads(r'''${output}''')    json
    [Return]    ${object}

Run Iperf Test Client for MCAST
    [Arguments]    ${src}    ${server}    ${args}
    [Documentation]    Login to ${src} and run the iperf client against ${server} using ${args}.
    ...    Return a Dictionary containing the results of the test.
    ${output}    ${stderr}    ${rc}=    Execute Remote Command    sudo iperf -c ${server} ${args} | jq -M -c '.'
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Should Be Equal As Integers    ${rc}    0
    ${object}=    Evaluate    json.loads(r'''${output}''')    json
    [Return]    ${object}

RestoreONUs
    [Documentation]    Restore all connected ONUs
    [Arguments]    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${container_type}=    Get Variable Value    ${src['container_type']}    "null"
        ${container_name}=    Get Variable Value    ${src['container_name']}    "null"
        ${onu_type}=    Get Variable Value    ${src['onu_type']}    "null"
        #Get ens6f0 from ens6f0.22
        ${if_name}=    Replace String Using Regexp    ${src['dp_iface_name']}    \\..*    \
        Run Keyword IF    '${onu_type}' == 'alpha'    AlphaONURestoreDefault    ${src['ip']}    ${src['user']}
        ...    ${src['pass']}    ${if_name}    admin    admin    ${container_type}    ${container_name}
    END

AlphaONURestoreDefault
    [Documentation]    Restore the Alpha ONU to factory setting
    [Arguments]    ${rg_ip}    ${rg_user}    ${rg_pass}    ${onu_ifname}
    ...    ${onu_user}    ${onu_pass}    ${container_type}=${None}    ${container_name}=${None}
    ${output}=    Login And Run Command On Remote System    sudo ifconfig ${onu_ifname} 192.168.1.3/24
    ...    ${rg_ip}    ${rg_user}    ${rg_pass}    ${container_type}    ${container_name}
    ${cmd}	Catenate
    ...    (echo open "192.168.1.1"; sleep 1;
    ...    echo "${onu_user}"; sleep 1;
    ...    echo "${onu_pass}"; sleep 1;
    ...    echo "restoredefault"; sleep 1) | telnet
    ${output}=    Login And Run Command On Remote System    ${cmd}
    ...    ${rg_ip}    ${rg_user}    ${rg_pass}    ${container_type}    ${container_name}
    Log To Console    ${output}
    ${output}=    Login And Run Command On Remote System    sudo ifconfig ${onu_ifname} 0
    ...    ${rg_ip}    ${rg_user}    ${rg_pass}    ${container_type}    ${container_name}

Create traffic with each pbit and capture at other end
    [Documentation]    Generates upstream traffic using Mausezahn tool
    ...    with each pbit and validates reception at other end using tcpdump
    [Arguments]    ${target_ip}    ${target_iface}    ${src_iface}
    ...    ${packet_count}    ${packet_type}    ${target_port}    ${vlan}    ${tcpdump_filter}
    ...    ${dst_ip}    ${dst_user}    ${dst_pass}    ${dst_container_type}    ${dst_container_name}
    ...    ${src_ip}    ${src_user}    ${src_pass}    ${src_container_type}    ${src_container_name}
    FOR    ${pbit}    IN RANGE    8
        Execute Remote Command    sudo pkill mausezahn
        ...    ${src_ip}    ${src_user}    ${src_pass}    ${src_container_type}    ${src_container_name}
        ${var1}=    Set Variable    sudo mausezahn ${src_iface} -B ${target_ip} -c ${packet_count} -d 100m
        ${var2}=    Set Variable    -t ${packet_type} "dp=${target_port}" -p 1472 -Q ${pbit}:${vlan}
        ${cmd}=    Set Variable    ${var1} ${var2}
        Start Remote Command    ${cmd}    ${src_ip}    ${src_user}    ${src_pass}
        ...    ${src_container_type}    ${src_container_name}
        ${output}    ${stderr}    ${rc}=    Execute Remote Command
        ...    sudo tcpdump -l -U -c 30 -i ${target_iface} -e ${tcpdump_filter}
        ...    ${dst_ip}    ${dst_user}    ${dst_pass}    ${dst_container_type}    ${dst_container_name}
        ...    timeout=30 seconds
        Execute Remote Command    sudo pkill mausezahn
        ...    ${src_ip}    ${src_user}    ${src_pass}    ${src_container_type}    ${src_container_name}
        # VOL-3262:  I'm seeing untagged downstream traffic at RG for pbit 0.  According to Girish this is
        # incorrect behavior.  Simplify the following check when VOL-3262 is resolved.
        Run Keyword If    ${pbit}==0 and "${tcpdump_filter}"=="udp"
        ...    Should Match Regexp    ${output}    \\.${target_port}: UDP,
        ...    ELSE    Should Match Regexp    ${output}    , p ${pbit},.*\\.${target_port}: UDP,
    END
