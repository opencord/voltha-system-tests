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
Resource          ./voltctl.robot
Resource          ./vgc.robot

*** Keywords ***
Check CLI Tools Configured
    [Documentation]    Tests that use 'voltctl' and 'kubectl' should execute this keyword in suite setup
    # check voltctl and kubectl configured
    ${voltctl_rc}    ${voltctl_output}=    Run And Return Rc And Output    voltctl -c ${VOLTCTL_CONFIG} device list
    Log    ${voltctl_output}
    ${kubectl_rc}    ${kubectl_output}=    Run And Return Rc And Output    kubectl get pods
    Log    ${kubectl_output}
    Run Keyword If    ${voltctl_rc} != 0 or ${kubectl_rc} != 0    FATAL ERROR
    ...    VOLTCTL and KUBECTL not configured. Please configure before executing tests.

Common Test Suite Setup
    [Documentation]    Setup the test suite
    Set Global Variable    ${KUBECTL_CONFIG}    %{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    %{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${VGC_REST_IP}=    Get Environment Variable    VGC_REST_IP    ${k8s_node_ip}
    ${VGC_SSH_IP}=     Get Environment Variable    VGC_SSH_IP     ${k8s_node_ip}
    Set Global Variable    ${VGC_REST_IP}
    Set Global Variable    ${VGC_SSH_IP}
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
    Check CLI Tools Configured
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create VGC Session
    ${num_olts}    Get Length    ${olts}
    ${list_olts}    Create List
    # Create olt list from the configuration file
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${ip}    Evaluate    ${olts}[${I}].get("ip")
        ${user}    Evaluate    ${olts}[${I}].get("user")
        ${pass}    Evaluate    ${olts}[${I}].get("pass")
        ${serial_number}    Evaluate    ${olts}[${I}].get("serial")
        ${olt_ssh_ip}    Evaluate    ${olts}[${I}].get("sship")
        ${type}    Evaluate    ${olts}[${I}].get("type")
        ${power_switch_port}    Evaluate    ${olts}[${I}].get("power_switch_port")
        ${orig_olt_port}    Evaluate    ${olts}[${I}].get("oltPort")
        ${port}=    Set Variable If    "${orig_olt_port}" == "None"    ${OLT_PORT}    ${orig_olt_port}
        ${onu_count}=    Get ONU Count For OLT    ${hosts.src}    ${serial_number}
        ${onu_list}=    Get ONU List For OLT    ${hosts.src}    ${serial_number}
        ${olt}    Create Dictionary    ip    ${ip}    user    ${user}    pass
        ...    ${pass}    sn    ${serial_number}   onucount   ${onu_count}    type    ${type}
        ...    sship    ${olt_ssh_ip}    oltport    ${port}    powerswitchport    ${power_switch_port}
        ...    onus    ${onu_list}
        Append To List    ${list_olts}    ${olt}
    END
    ${num_all_onus}=    Get Length    ${hosts.src}
    ${num_all_onus}=    Convert to String    ${num_all_onus}
    #send sadis file to vgc
    ${sadis_file}=    Get Variable Value    ${sadis.file}
    Log To Console    \nSadis File:${sadis_file}
    Run Keyword Unless    '${sadis_file}' == '${None}'    Send File To VGC    ${sadis_file}   # apps/
    Set Suite Variable    ${num_all_onus}
    Set Suite Variable    ${num_olts}
    Set Suite Variable    ${list_olts}
    ${olt_count}=    Get Length    ${list_olts}
    Set Suite Variable    ${olt_count}
    @{container_list}=    Create List    ${OLT_ADAPTER_APP_LABEL}    adapter-open-onu    voltha-api-server
    ...    voltha-ro-core    voltha-rw-core-11    voltha-rw-core-12    voltha-ofagent
    Set Suite Variable    ${container_list}
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}

Get ONU Count For OLT
    [Arguments]    ${src}    ${serial_number}
    [Documentation]    Gets ONU Count for the specified OLT
    ${src_length}=    Get Length    ${src}
    ${count}=    Set Variable    0
    FOR    ${I}    IN RANGE    0     ${src_length}
        ${sn}    Evaluate    ${src}[${I}].get("olt")
        ${count}=    Run Keyword If    '${serial_number}' == '${sn}'    Evaluate    ${count} + 1
        ...          ELSE  Set Variable  ${count}
    END
    RETURN    ${count}

Get ONU List For OLT
    [Arguments]    ${src}    ${serial_number}
    [Documentation]    Gets ONU List for the specified OLT
    ${src_length}=    Get Length    ${src}
    ${onu_list}=    Create List
    FOR    ${I}    IN RANGE    0     ${src_length}
        ${sn}    Evaluate    ${src}[${I}].get("olt")
        Run Keyword If    '${serial_number}' == '${sn}'    Append To List     ${onu_list}    ${src}[${I}][onu]
        ...  ELSE  Set Variable  ${onu_list}
    END
    RETURN    ${onu_list}

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
    RETURN    ${result}

Check Remote File Contents For WPA Logs
    [Arguments]    ${file_should_exist}    ${file}    ${pattern}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}    ${prompt}=~$
    [Documentation]    Checks for particular pattern count in a file
    ${result}=    Login And Run Command On Remote System
    ...    cat ${file} | grep '${pattern}' | wc -l    ${ip}    ${user}    ${pass}
    ...    ${container_type}    ${container_name}    ${prompt}
    RETURN    ${result}

Perform Sanity Test DT
    [Documentation]    This keyword iterate all OLTs and performs Sanity Test Procedure for DT workflow
    ...    For repeating sanity test without subscriber changes set flag supress_add_subscriber=True.
    ...    In all other (common) cases flag has to be set False (default).
    [Arguments]    ${supress_add_subscriber}=False
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${num_onus}=    Set Variable    ${list_olts}[${J}][onucount]
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        Perform Sanity Test DT Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}    ${num_onus}
        ...    ${supress_add_subscriber}
        # Verify VGC Flows
        # Number of Access Flows on VGC equals 4 * the Number of Active ONUs (2 for each downstream and upstream)
        ${vgc_flows_count}=    Evaluate    4 * ${num_onus}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added Count DT   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
        ...    ${vgc_flows_count}
        # Verify LLDP flow in VGC
        #Wait Until Keyword Succeeds    ${timeout}    5s
        #...     Verify LLDP Flow Added      ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}      1
        # Verify VOLTHA Flows
        # Number of per OLT Flows equals Twice the Number of Active ONUs (each for downstream and upstream) + 1 for LLDP
        ${olt_flows}=    Evaluate    2 * ${num_onus}
        # Number of per ONU Flows equals 2 (one each for downstream and upstream)
        ${onu_flows}=    Set Variable    2
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows
        ...    ${olt_flows}    ${olt_device_id}
        ${List_ONU_Serial}    Create List
        Set Suite Variable    ${List_ONU_Serial}
        Build ONU SN List    ${List_ONU_Serial}    ${olt_serial_number}
        Log    ${List_ONU_Serial}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONU Flows
        ...    ${List_ONU_Serial}    ${onu_flows}
    END


Perform Sanity Test DT Per OLT
    [Arguments]    ${of_id}    ${nni_port}    ${olt_serial_number}    ${num_onus}    ${supress_add_subscriber}=False
    [Documentation]    This keyword performs Sanity Test Procedure for DT Workflow
    ...    Sanity test performs dhcp and pings (without EAPOL and DHCP flows) for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.
    ...    For repeating sanity test without subscriber changes set flag supress_add_subscriber=True.
    ...    In all other (common) cases flag has to be set False (default).
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}    ${src['uni_id']}
        # Check ONU port is Enabled in VGC
        Wait Until Keyword Succeeds   120s   2s
        ...    Verify UNI Port Is Enabled      ${src['onu']}    ${src['uni_id']}
        Run Keyword Unless    ${supress_add_subscriber}
        ...     Add Subscriber Details   ${of_id}    ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT in VGC   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['s_tag']}
        # Verify ONU state in voltha
        ${onu_reasons}=  Create List     omci-flows-pushed
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    onu-reenabled
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=${onu_reasons}
        # Verify Meters in VGC
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Meters in VGC Ietf    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}    ${onu_port}
        # TODO: Yet to Verify on the GPON based Physical POD (VOL-2652)
        Run Keyword If    ${has_dataplane}    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END

Perform Sanity Test DT FTTB
    [Documentation]    This keyword iterate all OLTs and performs Sanity Test Procedure for DT-FTTB workflow
    ...    For repeating sanity test without subscriber changes set flag supress_add_subscriber=True.
    ...    In all other (common) cases flag has to be set False (default).
    [Arguments]    ${supress_add_subscriber}=False
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        Perform Sanity Test DT FTTB Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}
        ...    ${supress_add_subscriber}
    END

Perform Sanity Test DT FTTB Per OLT
    [Arguments]    ${of_id}    ${nni_port}    ${olt_serial_number}    ${supress_add_subscriber}=False
    [Documentation]    This keyword performs Sanity Test Procedure for DT-FTTB Workflow
    ...    Sanity test performs dhcp and pings (without EAPOL and DHCP flows) for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.
    ...    For repeating sanity test without subscriber changes set flag supress_add_subscriber=True.
    ...    In all other (common) cases flag has to be set False (default).
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in VGC    ${src['onu']}    ${of_id}    ${src['uni_id']}
        # Check ONU port is Enabled in VGC
        Wait Until Keyword Succeeds   120s   2s
        ...    Verify UNI Port Is Enabled      ${src['onu']}    ${src['uni_id']}
        Run Keyword Unless    ${supress_add_subscriber}
        ...     Add Subscriber Details   ${of_id}    ${onu_port}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify VGC Flows Added For DT FTTB    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['service']}
        # Verify that the Subscriber is present at the given location
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Programmed Subscribers DT FTTB    ${of_id}
        ...    ${onu_port}    ${src['service']}
        # Verify ONU state in voltha
        ${onu_reasons}=  Create List     omci-flows-pushed
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    onu-reenabled
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=${onu_reasons}
        # Verify Meters in VGC
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Meters in VGC Ietf    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}    ${onu_port}
        ...    FTTB_SUBSCRIBER_TRAFFIC
        Run Keyword If    ${has_dataplane}    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END

Validate All OLT Flows
    [Documentation]    This keyword iterate all OLTs and performs Sanity Test Procedure for DT workflow
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${num_onus}=    Set Variable    ${list_olts}[${J}][onucount]
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        # Verify VGC Flows
        # Number of Access Flows on VGC equals 4 * the Number of Active ONUs (2 for each downstream and upstream)
        ${vgc_flows_count}=    Evaluate    4 * ${num_onus}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added Count DT    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
        ...    ${vgc_flows_count}
        # Verify VOLTHA Flows
        # Number of per OLT Flows equals Twice the Number of Active ONUs (each for downstream and upstream) + 1 for LLDP
        ${olt_flows}=    Evaluate    2 * ${num_onus}
        # Number of per ONU Flows equals 2 (one each for downstream and upstream)
        ${onu_flows}=    Set Variable    2
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Flows    ${olt_flows}
        ...    ${olt_device_id}
        ${List_ONU_Serial}    Create List
        Set Suite Variable    ${List_ONU_Serial}
        Build ONU SN List    ${List_ONU_Serial}    ${olt_serial_number}
        Log    ${List_ONU_Serial}
        Run Keyword    Wait Until Keyword Succeeds    ${timeout}    5s    Validate ONU Flows
        ...    ${List_ONU_Serial}    ${onu_flows}
    END

Setup Soak
    [Documentation]    Pre-test Setup for Soak Job
    ${olt_ids}    Create List
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        ${olt_device_id}=    Get Device ID From SN    ${olt_serial_number}
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        ${olt}    Create Dictionary    device_id    ${olt_device_id}    logical_id    ${logical_id}
        ...    of_id    ${of_id}    sn    ${olt_serial_number}
        Append To List    ${olt_ids}    ${olt}
    END
    Set Global Variable    ${olt_ids}

Setup
    [Documentation]    Pre-test Setup
    [Arguments]    ${skip_empty_device_list_test}=False
    #test for empty device list
    Run Keyword If    '${skip_empty_device_list_test}'=='False'    Test Empty Device List
    # TBD: Need for this Sleep
    Run Keyword If    ${has_dataplane}    Sleep    180s
    # Create a list of olt ids (logical and device_id)
    ${olt_ids}    Create List
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #create/preprovision device
        ${olt_device_id}=    Run Keyword If    "${list_olts}[${I}][type]" == "${None}"
        ...    Create Device    ${list_olts}[${I}][ip]    ${list_olts}[${I}][oltport]
        ...    ELSE    Create Device    ${list_olts}[${I}][ip]    ${list_olts}[${I}][oltport]    ${list_olts}[${I}][type]
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #Set Suite Variable    ${olt_device_id}
        #validate olt states
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}    by_dev_id=True
        Sleep    5s
        Enable Device    ${olt_device_id}
        # Increasing the timer to incorporate wait time for in-band
        Wait Until Keyword Succeeds    540s    5s
        ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        # Set Suite Variable    ${logical_id}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC
        ...    ${olt_serial_number}
        ${olt}    Create Dictionary    device_id    ${olt_device_id}    logical_id    ${logical_id}
        ...    of_id    ${of_id}    sn    ${olt_serial_number}
        Append To List    ${olt_ids}    ${olt}
    END
    Set Global Variable    ${olt_ids}

Get ofID From OLT List
    [Documentation]    Retrieves the corresponding of_id for the OLT serial number specified
    [Arguments]      ${serial_number}
    FOR    ${I}    IN RANGE    0    ${olt_count}
        ${sn}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${of_id}=    Run Keyword IF    "${serial_number}"=="${sn}"
        ...    Get From Dictionary    ${olt_ids}[${I}]    of_id    ELSE    Set Variable    ${of_id}
    END
    RETURN    ${of_id}

Get OLTDeviceID From OLT List
    [Documentation]    Retrieves the corresponding olt_device_id  for the OLT serial number specified
    [Arguments]      ${serial_number}
    ${olt_device_id}=    Set Variable    0
    FOR    ${I}    IN RANGE    0    ${olt_count}
        ${sn}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Run Keyword IF    "${serial_number}"=="${sn}"
        ...    Get From Dictionary    ${olt_ids}[${I}]    device_id    ELSE    Set Variable    ${olt_device_id}
    END
    RETURN    ${olt_device_id}

Get Num of Onus From OLT SN
    [Documentation]    Retrieves the corresponding number of ONUs for a given OLT based on serial number specified
    [Arguments]      ${serial_number}
    ${num_of_olt_onus}=    Set Variable    0
    FOR    ${I}    IN RANGE    0    ${olt_count}
        ${sn}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${num_of_olt_onus}=    Run Keyword IF    "${serial_number}"=="${sn}"
        ...    Get From Dictionary    ${list_olts}[${I}]    onucount    ELSE    Set Variable    ${num_of_olt_onus}
    END
    RETURN    ${num_of_olt_onus}

Validate ONUs After OLT Disable
    [Documentation]    Validates the ONUs state in Voltha, ONUs port state in VGC
    ...    and that pings do not succeed After corresponding OLT is Disabled
    [Arguments]      ${num_onus}    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in VGC    ${src['onu']}
        ...    ${of_id}
        ${valid_onu_states}=    Create List    stopping-openomci    omci-flows-deleted
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=True    onu_reason=${valid_onu_states}
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Disabled   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

Delete All Devices and Verify
    [Documentation]    Remove any devices from VOLTHA and VGC
    [Arguments]    ${maclearning_enabled}=False
    # Clear devices from VOLTHA
    ${resp}=    Get Request    VGC    devices
    ${jsondata}=    To Json   ${resp.content}
    ${length}=    Get Length    ${jsondata['devices']}
    ${matched}=    Set Variable     False
    ${matched}=    Set Variable If   '${length}' == '${num_olts}'    True    False
    Run Keyword If     ${matched}     Disable Devices In Voltha    Root=true
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Devices Disabled In Voltha    Root=true
    Delete Devices In Voltha    Root=true
    Wait Until Keyword Succeeds    ${timeout}    2s    Test Empty Device List
    FOR    ${I}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${I}
        ${device_id}=    Get From Dictionary    ${value}    id
        ${olt_serial_number}=    Get From Dictionary    ${value}    serial
        #${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Deleted Device Cleanup In VGC    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${olt_serial_number}    ${device_id}
        ...    ${maclearning_enabled}
    END
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Cleanup In ETCD    ${INFRA_NAMESPACE}

Teardown
    [Documentation]    kills processes and cleans up interfaces on src+dst servers
    Run Keyword If    ${has_dataplane}    Clean Up Linux

Teardown Suite
    [Documentation]    Clean up device if desired
    Start Logging Setup or Teardown  Teardown-${SUITE NAME}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${teardown_device}    Deactivate Subscribers In VGC
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    Run Keyword And Continue On Failure    Collect Logs
    #Close All VGC SSH Connections
    Run Keyword If    ${has_dataplane}    Clean Up All Nodes
    Stop Logging Setup or Teardown    Teardown-${SUITE NAME}

Delete Device and Verify
    [Arguments]    ${olt_serial_number}
    [Documentation]    Disable -> Delete devices via voltctl and verify its removed
    ${olt_device_id}=    Get Device ID From SN    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Sleep    5s
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    voltctl -c ${VOLTCTL_CONFIG} device delete ${olt_device_id}
    Sleep    50s
    Should Be Equal As Integers    ${rc}    0
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed    ${olt_device_id}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    15s
    ...    Validate Deleted Device Cleanup In VGC    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${olt_serial_number}    ${olt_device_id}

Disable Enable PON Port Per OLT DT
    [Arguments]    ${olt_serial_number}
    [Documentation]    This keyword disables and then enables OLT PON port and
    ...    also validate ONUs for each corresponding case
    ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
    ${olt_pon_port_list}=    Retrieve OLT PON Ports    ${olt_device_id}
    ${olt_pon_port_list_len}=    Get Length    ${olt_pon_port_list}
    FOR    ${INDEX0}    IN RANGE    0    ${olt_pon_port_list_len}
        ${olt_pon_port}=    Get From List    ${olt_pon_port_list}    ${INDEX0}
        ${olt_peer_list}=    Retrieve Peer List From OLT PON Port    ${olt_device_id}    ${olt_pon_port}
        ${olt_peer_list_len}=    Get Length    ${olt_peer_list}
        # Disable the OLT PON Port and Validate OLT Device
        DisableOrEnable OLT PON Port    disable    ${olt_device_id}    ${olt_pon_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT PON Port Status    ${olt_device_id}    ${olt_pon_port}
        ...    DISABLED    DISCOVERED
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate ONUs for PON OLT Disable DT    ${olt_serial_number}    ${olt_peer_list}
        # Enable the OLT PON Port back, and check ONU status are back to "ACTIVE"
        DisableOrEnable OLT PON Port    enable    ${olt_device_id}    ${olt_pon_port}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT PON Port Status    ${olt_device_id}    ${olt_pon_port}
        ...    ENABLED    ACTIVE
        ${olt_peer_list_new}=    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Retrieve Peer List From OLT PON Port    ${olt_device_id}    ${olt_pon_port}    ${olt_peer_list_len}
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate ONUs for PON OLT Enable DT    ${olt_serial_number}    ${olt_peer_list_new}
    END

Validate ONUs for PON OLT Disable DT
    [Arguments]    ${olt_sn}    ${olt_peer_list}
    [Documentation]     This keyword validates that Ping fails for ONUs connected to Disabled OLT PON port
    ...    And Pings succeed for other Active OLT PON port ONUs
    ...    Also it removes subscriber and deletes ONUs for Disabled OLT PON port to replicate DT workflow
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_sn}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in VGC    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${matched}=    Match ONU in PON OLT Peer List    ${olt_peer_list}    ${onu_device_id}
        ${valid_onu_states}=    Create List    stopping-openomci    omci-flows-deleted
        Run Keyword If    ${matched}
        ...    Run Keywords
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    onu=True    onu_reason=${valid_onu_states}
        ...    AND    Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Disabled   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        ...    AND    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
        # Remove Subscriber Access (To replicate DT workflow)
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s     Remove Subscriber Access   ${of_id}   ${onu_port}
        #Execute VGC CLI Command use single connection
        #...    ${VGC_SSH_IP}    ${VGC_SSH_PORT}    volt-remove-subscriber-access ${of_id} ${onu_port}
        # Delete ONU Device (To replicate DT workflow)
        ...    AND    Delete Device    ${onu_device_id}
        # Additional Sleep to let subscriber and ONU delete process
        ...    AND    Sleep    10s
        ...    ELSE
        ...    Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
    END

Validate ONUs for PON OLT Enable DT
    [Arguments]    ${olt_sn}    ${olt_peer_list}
    [Documentation]    This keyword validates Ping succeeds for all Enabled/Acitve OLT PON ports
    ...    Also performs subscriberAdd/DHCP/Ping for the ONUs on Re-Enabled OLT PON port
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_sn}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in VGC    ${src['olt']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in VGC    ${of_id}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in VGC    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${matched}=    Match ONU in PON OLT Peer List    ${olt_peer_list}    ${onu_device_id}
        Run Keyword If    ${matched}
        ...    Run Keywords
        # Perform Cleanup
        ...    Run Keyword If    ${has_dataplane}    Clean Up Linux    ${onu_device_id}
        # Verify ONU port status
        ...    AND    Wait Until Keyword Succeeds   120s   2s
        ...    Verify UNI Port Is Enabled    ${src['onu']}    ${src['uni_id']}
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2
       # ...    Execute VGC CLI Command use single connection    ${VGC_SSH_IP}    ${VGC_SSH_PORT}
       # ...    volt-add-subscriber-access ${of_id} ${onu_port}
        ...   Add Subscriber Details   ${of_id}   ${onu_port}
        # Verify ONU state in voltha
        ...    AND    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Verify subscriber access flows are added for the ONU port
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU DT In VGC   ${VGC_SSH_IP}    ${VGC_SSH_PORT}    ${of_id}
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
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}
        ...    ${src['container_name']}
    END

Match ONU in PON OLT Peer List
    [Arguments]    ${olt_peer_list}    ${onu_device_id}
    [Documentation]     This keyword matches if ONU device is present in OLT PON port peer list
    ${matched}=    Set Variable    False
    FOR    ${olt_peer}    IN    @{olt_peer_list}
        ${matched}=    Set Variable If    '${onu_device_id}' == '${olt_peer}'    True    False
        Exit For Loop If    ${matched}
    END
    RETURN    ${matched}

Collect Logs
    [Documentation]    Collect Logs from voltha for various commands
    Run Keyword and Ignore Error    Get Device List from Voltha
    FOR    ${I}    IN RANGE    0    ${num_olts}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${olt_ids}[${I}][device_id]
        Run Keyword and Ignore Error    Get Logical Device Output from Voltha    ${olt_ids}[${I}][logical_id]
    END

Verify ping is successful except for given device
    [Arguments]    ${num_onus}    ${exceptional_onu}
    [Documentation]    Checks that ping for all the devices are successful except the given ONU.
    ${pingStatus}     Set Variable    True
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${pingStatus}     Run Keyword If    '${src['onu']}' == '${exceptional_onu}'    Set Variable     False
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    ${pingStatus}    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}   ${src['container_type']}    ${src['container_name']}
    END

Verify ping is successful for ONUs not on this OLT
    [Arguments]    ${num_all_onus}    ${exceptional_olt_id}
    [Documentation]    Checks that pings work for all the ONUs except for the ONUs on the given OLT.
    #${pingStatus}     Set Variable    True
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${olt_device_id}=    Get Device ID From SN    ${src['olt']}
        Continue For Loop If    "${olt_device_id}"=="${exceptional_olt_id}"
        #${pingStatus}     Run Keyword If    '${olt_device_id}' == '${exceptional_olt_id}'    Set Variable     False
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}   ${src['container_type']}    ${src['container_name']}
    END

Echo Message to OLT Logs
    [Arguments]    ${message}
    [Documentation]     Echoes ${message} into the OLT logs
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${olt_user}    Evaluate    ${olts}[${I}].get("user")
        ${olt_pass}    Evaluate    ${olts}[${I}].get("pass")
        ${olt_ssh_ip}    Evaluate    ${olts}[${I}].get("sship")
        ${olt_type}    Evaluate    ${olts}[${I}].get("type")
        Continue For Loop If    "${olt_user}" == "${None}"
        Continue For Loop If    "${olt_pass}" == "${None}"
        ${command_timeout}=    Set Variable If   "${olt_type}"=="adtranolt"    300s    180s
        Wait Until Keyword Succeeds    ${command_timeout}    10s    Execute Remote Command
        ...    printf '%s\n' '' '' '${message}' '' >> /var/log/openolt.log
        ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
        Wait Until Keyword Succeeds    ${command_timeout}    10s    Execute Remote Command
        ...    printf '%s\n' '' '' '${message}' '' >> /var/log/dev_mgmt_daemon.log
        ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
        Wait Until Keyword Succeeds    ${command_timeout}    10s    Execute Remote Command
        ...    printf '%s\n' '' '' '${message}' '' >> /var/log/openolt_process_watchdog.log
        ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
    END

Start Logging
    [Arguments]    ${label}
    [Documentation]    Start logging for test ${label}
    ${kail_process}=     Run Keyword If    "${container_log_dir}" != "${None}"   Start Process    kail    -n    ${NAMESPACE}
    ...    -n    ${INFRA_NAMESPACE}    cwd=${container_log_dir}   stdout=${label}-combined.log
    Set Test Variable    ${kail_process}
    Run Keyword If    ${has_dataplane}    Echo Message to OLT Logs     START ${label}

Start Logging Setup or Teardown
    [Arguments]    ${label}
    [Documentation]    Start logging for suite ${label}
    ${file}=    Replace String    ${label}    ${SPACE}  -
    ${kail_process}=     Run Keyword If    "${container_log_dir}" != "${None}"   Start Process    kail    -n    ${NAMESPACE}
    ...    -n    ${INFRA_NAMESPACE}    cwd=${container_log_dir}   stdout=${file}-combined.log
    Set Suite Variable    ${kail_process}
    Run Keyword If    ${has_dataplane}    Echo Message to OLT Logs     START ${label}

Stop Logging Setup or Teardown
    [Arguments]    ${label}
    [Documentation]    End logging for suite;
    Run    sync
    Run Keyword If    ${kail_process}    Terminate Process    ${kail_process}
    ${test_logfile}=    Run Keyword If    "${container_log_dir}" != "${None}"
    ...    Join Path    ${container_log_dir}    ${label}-combined.log
    Run Keyword If    ${has_dataplane}    Echo Message to OLT Logs     END ${label}

Stop Logging
    [Arguments]    ${label}
    [Documentation]    End logging for test; remove logfile if test passed and ${logging} is set to False
    Run    sync
    Run Keyword If    ${kail_process}    Terminate Process    ${kail_process}
    ${test_logfile}=    Run Keyword If    "${container_log_dir}" != "${None}"
    ...    Join Path    ${container_log_dir}    ${label}-combined.log
    Run Keyword If Test Passed
    ...    Run Keyword If    "${logging}" == "False"
    ...    Run Keyword If    "${test_logfile}" != "${None}"
    ...    Remove File    ${test_logfile}
    Run Keyword If    ${has_dataplane}    Echo Message to OLT Logs     END ${label}

Clean Up Linux
    [Documentation]    Kill processes and clean up interfaces on src+dst servers
    [Arguments]    ${onu_id}=${EMPTY}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
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

Clean Up Linux Per OLT
    [Documentation]    Kill processes and clean up interfaces on src+dst servers
    [Arguments]    ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${sn}=    Get Device ID From SN    ${src['olt']}
        #Continue For Loop If    '${onu_id}' != '${EMPTY}' and '${onu_id}' != '${onu_device_id}'
        Continue For Loop If    '${olt_serial_number}' == '${sn}'
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
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Execute Remote Command    sudo pkill dhclient    ${src['ip']}
        ...    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

Clean WPA Process
    [Documentation]    Kills wpa_supplicant processes only for all RGs
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
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

Should Be Lower Than
    [Documentation]    Verify that value_1 is < value_2
    [Arguments]    ${value_1}    ${value_2}
    Run Keyword If    ${value_1} >= ${value_2}
    ...    Fail    The value ${value_1} is not lower than ${value_2}

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
    RETURN     ${output}

Parse RFC3339
    [Documentation]     Parse an RFC3339 timestamp
    [Arguments]    ${dateStr}
    ${rc}    ${output}=    Run and Return Rc and Output     date --date="${dateStr}" "+%s"
    Should Be Equal As Numbers    ${rc}    0
    RETURN    ${output}

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
    RETURN    ${stdout}    ${stderr}    ${rc}

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
    ${output}    ${stderr}    ${rc}=    Execute Remote Command    iperf3 -J -c ${server} ${args} -l 1024 -M 1350 | jq -M -c '.'
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Should Be Equal As Integers    ${rc}    0
    ${object}=    Evaluate    json.loads(r'''${output}''')    json
    RETURN    ${object}

Run Iperf Test Client for MCAST
    [Arguments]    ${src}    ${server}    ${args}
    [Documentation]    Login to ${src} and run the iperf client against ${server} using ${args}.
    ...    Return a Dictionary containing the results of the test.
    ${output}    ${stderr}    ${rc}=    Execute Remote Command    sudo iperf -c ${server} ${args} | jq -M -c '.'
    ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    Should Be Equal As Integers    ${rc}    0
    ${object}=    Evaluate    json.loads(r'''${output}''')    json
    RETURN    ${object}

Run Ping In Background
    [Arguments]    ${output_file}    ${dst_ip}    ${iface}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]    Runs the 'ping' on remote system in background and stores the result in a file
    ${result}=    Login And Run Command On Remote System
    ...    echo "ping -I ${iface} ${dst_ip} > ${output_file} &" > ping.sh; chmod +x ping.sh; ./ping.sh
    ...    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Log    ${result}

Stop Ping Running In Background
    [Arguments]    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]    Stops the 'ping' running in background on remote system
    ${cmd}=    Run Keyword If    '${container_type}' == 'LXC' or '${container_type}' == 'K8S'
    ...    Set Variable    kill -SIGINT `pgrep ping`
    ...    ELSE
    ...    Set Variable    sudo kill -SIGINT `pgrep ping`
    ${result}=    Login And Run Command On Remote System
    ...    ${cmd}    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Log    ${result}

Retrieve Remote File Contents
    [Documentation]    Retrieves the contents of the file on remote system
    [Arguments]    ${file}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}    ${prompt}=~$
    ${output}=    Login And Run Command On Remote System
    ...    cat ${file}
    ...    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}    ${prompt}
    RETURN    ${output}

RestoreONUs
    [Documentation]    Restore all connected ONUs
    [Arguments]    ${num_all_onus}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
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
    ${cmd}    Catenate
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
    ...    ${packet_count}    ${packet_type}    ${c_vlan}    ${s_vlan}    ${direction}    ${tcpdump_filter}
    ...    ${dst_ip}    ${dst_user}    ${dst_pass}    ${dst_container_type}    ${dst_container_name}
    ...    ${src_ip}    ${src_user}    ${src_pass}    ${src_container_type}    ${src_container_name}
    FOR    ${pbit}    IN RANGE    8
        Execute Remote Command    sudo pkill mausezahn
        ...    ${src_ip}    ${src_user}    ${src_pass}    ${src_container_type}    ${src_container_name}
        ${var1}=    Set Variable    sudo mausezahn ${src_iface} -B ${target_ip} -c ${packet_count}
        ${var2}=    Run Keyword If    "${direction}"=="downstream"
        ...    Set Variable    -t ${packet_type} "dp=80, flags=rst, p=aa:aa:aa" -Q ${pbit}:${s_vlan},${pbit}:${c_vlan}
        ...    ELSE
        ...    Set Variable    -t ${packet_type} "dp=80, flags=rst, p=aa:aa:aa" -Q ${pbit}:${c_vlan}
        ${cmd}=    Set Variable    ${var1} ${var2}
        Start Remote Command    ${cmd}    ${src_ip}    ${src_user}    ${src_pass}
        ...    ${src_container_type}    ${src_container_name}
        ${output}    ${stderr}    ${rc}=    Execute Remote Command
        ...    sudo tcpdump -l -U -c 30 -i ${target_iface} -e ${tcpdump_filter}
        ...    ${dst_ip}    ${dst_user}    ${dst_pass}    ${dst_container_type}    ${dst_container_name}
        ...    timeout=30 seconds
        Execute Remote Command    sudo pkill mausezahn
        ...    ${src_ip}    ${src_user}    ${src_pass}    ${src_container_type}    ${src_container_name}
        Run Keyword If    "${tcpdump_filter}"=="tcp"
        ...    Should Match Regexp    ${output}    , p ${pbit},
    END

Determine Number Of ONU
    [Arguments]    ${olt_serial_number}=${EMPTY}    ${num_onus}=${num_all_onus}
    [Documentation]    Determine the number of different ONUs for the given OLT taken from host.src
    ${onu_list}    Create List
    FOR    ${INDEX}    IN RANGE    0    ${num_onus}
        Continue For Loop If    "${olt_serial_number}"!="${hosts.src[${INDEX}].olt}" and "${olt_serial_number}"!="${EMPTY}"
        ${onu_id}=    Get Index From List    ${onu_list}   ${hosts.src[${INDEX}].onu}
        Run Keyword If    -1 == ${onu_id}    Append To List    ${onu_list}    ${hosts.src[${INDEX}].onu}
    END
    ${real_num_onus}=    Get Length    ${onu_list}
    RETURN    ${real_num_onus}

Validate Cleanup In ETCD
    [Documentation]    The keyword verifies that device, ports, flows, meters are all cleared in ETCD
    [Arguments]    ${namespace}=default    ${defaultkvstoreprefix}=voltha/voltha_voltha
    ${podname}=    Set Variable    etcd
    ${kvstoreprefix}=    Get Kv Store Prefix    ${defaultkvstoreprefix}
    # Log Devices Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/devices --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Devices Data in Etcd!
    # Log Flows Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/flows --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Flows Data in Etcd!
    # Log LogicalDevices Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/logical_devices --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Logical Devices Data in Etcd!
    # Log LogicalFlows Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/logical_flows --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Logical Flows Data in Etcd!
    # Log LogicalMeters Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/logical_meters --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Logical Meters Data in Etcd!
    # Log LogicalPorts Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/logical_ports --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Logical Ports Data in Etcd!
    # Log Openolt Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/openolt --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Openolt Data in Etcd!
    # Log Openonu Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/openonu --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Openonu Data in Etcd!
    # Log Ports Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/ports --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Ports Data in Etcd!
    # Log ResourceInstances Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/resource_instances --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Resource Instances Data in Etcd!
    # Log ResourceManager Output and Verify Output Should be Empty
    ${commandget}=    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/${kvstoreprefix}/resource_manager --keys-only'
    ${result}=    Exec Pod In Kube    ${namespace}    ${podname}    ${commandget}
    Log    ${result}
    Should Be Empty    ${result}    Stale Resource Manager Data in Etcd!

Clean Up All Nodes
    [Documentation]    Login to each node and kill all stale lxc prcoesses
    ${num_nodes}=    Get Length    ${nodes}
    FOR    ${I}    IN RANGE    0    ${num_nodes}
        ${node_ip}=    Evaluate    ${nodes}[${I}].get("ip")
        ${node_user}=    Evaluate    ${nodes}[${I}].get("user")
        ${node_pass}=    Evaluate    ${nodes}[${I}].get("pass")
        Run Keyword And Continue On Failure    Start Remote Command    kill -9 `pidof lxc`
        ...    ${node_ip}    ${node_user}    ${node_pass}
    END

Reboot XGSPON ONU
    [Documentation]   Reboots the XGSPON ONU and verifies the ONU state after the reboot
    [Arguments]    ${olt_sn}    ${onu_sn}    ${reason}
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${serial_number}    Evaluate    ${olts}[${I}].get("serial")
        Continue For Loop If    "${serial_number}"!="${olt_sn}"
        ${board_tech}    Evaluate    ${olts}[${I}].get("board_technology")
        ${onu_device_id}=    Get Device ID From SN    ${onu_sn}
        Run Keyword If    "${board_tech}"=="XGS-PON"    Run Keywords
        ...    Reboot Device    ${onu_device_id}
        ...    AND    Wait Until Keyword Succeeds    120s    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${onu_sn}    onu=True    onu_reason=${reason}
    END

Set Non-Critical Tag for XGSPON Tech
    [Documentation]    Dynamically sets the test tag for xgs-pon based to non-critical
    FOR    ${I}    IN RANGE    0    ${num_olts}
        ${board_tech}    Evaluate    ${olts}[${I}].get("board_technology")
        Run Keyword If    "${board_tech}"=="XGS-PON"    Run Keywords
        ...    Set Tags    non-critical
        ...    AND    Exit For Loop
    END

Perform Reboot ONUs and OLTs Physically
    [Documentation]    This keyword reboots ONUs and OLTs physically
    ...    It runs only on the PODs that are configured with PowerSwitch that
    ...    controls the power off/on ONUs/OLT remotely (simulating a physical reboot)
    [Arguments]    ${power_cycle_olt}=False
    Power Switch Connection Suite    ${web_power_switch.ip}    ${web_power_switch.user}    ${web_power_switch.password}
    @{onu_list}=    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        # If the power switch port is not specified, continue
        Continue For Loop If    '${src["power_switch_port"]}' == '${None}'
        # Skip if we have already handled this ONU
        ${sn}=     Set Variable    ${src['onu']}
        ${onu_id}=    Get Index From List    ${onu_list}   ${sn}
        Continue For Loop If    -1 != ${onu_id}
        Append To List    ${onu_list}    ${sn}
        Disable Switch Outlet    ${src['power_switch_port']}
        Sleep    10s
        Enable Switch Outlet    ${src['power_switch_port']}
    END
    Pass Execution If    '${power_cycle_olt}'=='False'    Skipping OLT(s) Power Switch Reboot
    # Waiting extra time for the ONUs to come up
    Sleep    30s
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        ${power_switch_port}=    Get From Dictionary    ${list_olts}[${I}]    powerswitchport
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        # If the power switch port is not specified, continue
        Continue For Loop If    '${power_switch_port}' == '${None}'
        Disable Switch Outlet    ${power_switch_port}
        Sleep    10s
        Enable Switch Outlet    ${power_switch_port}
        Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s
        ...    Check Remote System Reachability    True    ${olt_ssh_ip}
    END
    # Waiting extra time for the ONUs to come up
    Sleep    60s

Count Number of UNI ports for OLT
    [Documentation]  Count Provisioned UNI ports, for ONUs connected with specified OLT
    [Arguments]    ${olt_serial_number}     ${type_of_service}
    ${num_of_provisioned_onus_ports}=      Evaluate     0
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        Continue For Loop If    "${type_of_service}"!="${src['service_type']}"
        ${num_of_provisioned_onus_ports}=      Evaluate     ${num_of_provisioned_onus_ports} + 1
    END
    RETURN    ${num_of_provisioned_onus_ports}
