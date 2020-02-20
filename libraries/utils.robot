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
    ${sadis_file}=    Get Variable Value    ${sadis.file}
    Log To Console    \nSadis File:${sadis_file}
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
        Run Keyword If    ${passed}    Exit For Loop
    END
    FOR    ${i}    IN RANGE    70
        ${output}=    Login And Run Command On Remote System
        ...    wpa_cli status | grep SUCCESS    ${ip}    ${user}
        ...    ${pass}    ${container_type}    ${container_name}
        ${passed}=    Run Keyword And Return Status    Should Contain    ${output}    SUCCESS
        Run Keyword If    ${passed}    Exit For Loop
    END

Validate Authentication After Reassociate
    [Arguments]    ${auth_pass}    ${iface}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]
    ...    Executes a particular reassociate request on the RG using wpa_cli.
    ...    auth_pass determines if authentication should pass
    WPA Reassociate    ${iface}    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'True'    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Remote File Contents    True    /tmp/wpa.log    authentication completed successfully
    ...    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'False'    Sleep    20s
    Run Keyword If    '${auth_pass}' == 'False'    Check Remote File Contents    False    /tmp/wpa.log
    ...    authentication completed successfully    ${ip}    ${user}    ${pass}
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
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Perform Authentication
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

Perform Sanity Test DT
    [Documentation]    This keyword performs Sanity Test Procedure for DT Workflow
    ...    Sanity test performs dhcp and pings (without EAPOL and DHCP flows) for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # TODO: Yet to Verify on the Physical POD
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END
    # Verify VOLTHA Flows (TODO: Add verification for ONOS Flows)
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

Setup
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ip}    ${olt_user}    ${olt_pass}
    Sleep    60s
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${EMPTY}    ${olt_device_id}
    Sleep    5s
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}

Delete All Devices and Verify
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Clear devices from VOLTHA
    Disable Devices In Voltha    Root=true
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Devices Disabled In Voltha    Root=true
    Delete Devices In Voltha    Root=true
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Empty Device List
    # Clear devices from ONOS
    Remove All Devices From ONOS
    ...    http://karaf:karaf@${k8s_node_ip}:${ONOS_REST_PORT}

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
    Sleep    50s
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
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOD
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
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
        ...    Verify ONU in AAA-Users    ${k8s_node_ip}    ${ONOS_SSH_PORT}     ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command    ${k8s_node_ip}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Validate DHCP and Ping    True    True
        ...    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Run Keyword And Continue On Failure
        ...    Validate Subscriber DHCP Allocation    ${k8s_node_ip}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error   Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error   Collect Logs
    END

Collect Logs
    [Documentation]    Collect Logs from voltha and onos cli for various commands
    Run Keyword and Ignore Error    Get Device List from Voltha
    Run Keyword and Ignore Error    Get Device Output from Voltha    ${olt_device_id}
    Run Keyword and Ignore Error    Get Logical Device Output from Voltha    ${logical_id}
    Get ONOS Status    ${k8s_node_ip}    ${ONOS_SSH_PORT}

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

Announce Message
    [Arguments]    ${message}
    [Documentation]    Announce a message that will be picked up by the log aggregator
    Run Process    kubectl    run    announcer    -ti    --rm    --restart    Never    --image    ubuntu
    ...     bash    --    -c    echo; sleep 1; echo ${message}; sleep 1; date --rfc-3339\=n ; sleep 1; echo; sleep 1

Start Logging
    [Arguments]    ${label}
    [Documentation]    Start logging for test ${label}
    ${kail_process}=     Run Keyword If    "${container_log_dir}" != "${None}"   Start Process    kail    -n    default
    ...    -n    voltha    cwd=${container_log_dir}   stdout=${label}-combined.log
    Set Test Variable    ${kail_process}

Stop Logging
    [Arguments]    ${label}
    [Documentation]    End logging for test; remove logfile if test passed
    Run    sync
    Run Keyword If    ${kail_process}    Terminate Process    ${kail_process}
    ${test_logfile}=    Run Keyword If    "${container_log_dir}" != "${None}"
    ...    Join Path    ${container_log_dir}    ${label}-combined.log
    Run Keyword If Test Passed    Run Keyword If    "${test_logfile}" != "${None}"    Remove File    ${test_logfile}

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
