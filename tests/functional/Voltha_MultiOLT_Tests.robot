# Copyright 2020-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
Documentation     Test various failure scenarios
Suite Setup       Setup Suite
Test Setup        Setup
Test Teardown     Teardown
Suite Teardown    Teardown Suite
Library           Collections
Library           String
Library           OperatingSystem
Library           XML
Library           RequestsLibrary
Library           ../../libraries/DependencyLibrary.py
Resource          ../../libraries/onos.robot
Resource          ../../libraries/voltctl.robot
Resource          ../../libraries/voltha.robot
Resource          ../../libraries/utils.robot
Resource          ../../libraries/k8s.robot
Resource          ../../variables/variables.robot
Resource          ../../libraries/power_switch.robot

*** Variables ***
${POD_NAME}       flex-ocp-cord
${KUBERNETES_CONF}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}    ~/pod-configs/kubernetes-configs
#${KUBERNETES_CONFIGS_DIR}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${NAMESPACE}      voltha
${INFRA_NAMESPACE}      default
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

*** Test Cases ***
Verify OLT after rebooting physically - MultipleOLT
    [Documentation]    Test the physical reboot of the OLT
    ...    Prerequisite : Subscriber are authenticated/DHCP/pingable state
    ...    Test performs a physical reboot on one of the OLTs, performs "reboot" from the OLT CLI
    ...    Validates that ONU on other OLTs are still functional
    [Tags]    functional   MultiOLTPhysicalReboot
    [Setup]    Start Logging    MultipleOlt-PhysicalOLTReboot
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    MultipleOlt-PhysicalOLTReboot
    # Execute the test when the number of OLTs are greater than one
    Pass Execution If    ${olt_count} == 1    Skipping test: just one OLT
    Clear All Devices Then Perform Setup And Sanity
    # Reboot the first OLT from the list of olts - rebooting from the OLT CLI
    ${olt_user}=    Get From Dictionary    ${list_olts}[0]    user
    ${olt_pass}=    Get From Dictionary    ${list_olts}[0]    pass
    ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[0]   sship
    ${olt_serial_number}=    Get From Dictionary    ${list_olts}[0]    sn
    ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
    Run Keyword If    ${has_dataplane}    Login And Run Command On Remote System
    ...    reboot    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}   prompt=#
    # validate that the ONUs on the other OLTs are still functional
    Verify ping is successful for ONUs not on this OLT     ${num_all_onus}    ${olt_device_id}
    # Validate that the ONUs on the rebooted OLT are not pingable
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[0]    sn
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Wait for the rebooted OLT to come back up
    ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[0]    sn
    ${olt_user}=    Get From Dictionary    ${list_olts}[0]    user
    ${olt_pass}=    Get From Dictionary    ${list_olts}[0]    pass
    ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[0]   sship
    ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s
    ...    Check Remote System Reachability    True    ${olt_ssh_ip}
    Wait Until Keyword Succeeds    360s    5s
    ...    Validate OLT Device    ENABLED    ACTIVE
    ...    REACHABLE    ${olt_serial_number}
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in ONOS    ${of_id}
        ${suppressaddsubscriber}=    Set Variable If    '${J}'=='0'    False    True
        Perform Sanity Test Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}   ${onu_count}
        ...    ${suppressaddsubscriber}
    END
    # Deleting OLT after test completes
    #Run Keyword If    ${has_dataplane}    Delete All Devices and Verify

Verify OLT Soft Reboot - MultipleOLT
    [Documentation]    Test soft reboot of the OLT using voltctl command
    ...     Verifies that when one OLT is rebooted other ONUs on other OLTs are
    ...     still functional
    [Tags]    MultiOLTSoftReboot    functional
    [Setup]    Start Logging    MultiOlt-OLTSoftReboot
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    MultiOlt-OLTSoftReboot
    # Execute the test when the number of OLTs are greater than one
    Pass Execution If    ${olt_count} == 1    Skipping test: just one OLT
    Clear All Devices Then Perform Setup And Sanity
    # Reboot the first OLT
    ${olt_user}=    Get From Dictionary    ${list_olts}[0]    user
    ${olt_pass}=    Get From Dictionary    ${list_olts}[0]    pass
    ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[0]   sship
    ${olt_serial_number}=    Get From Dictionary    ${list_olts}[0]    sn
    ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
    Wait Until Keyword Succeeds    360s    5s
    ...    Validate OLT Device    ENABLED    ACTIVE
    ...    REACHABLE    ${olt_serial_number}
    # Reboot the OLT using "voltctl device reboot" command
    Reboot Device    ${olt_device_id}
    # Wait for the OLT to actually go down
    Wait Until Keyword Succeeds    360s    5s    Validate OLT Device    ENABLED    UNKNOWN    UNREACHABLE
    ...    ${olt_serial_number}
    # validate that the ONUs on the other OLTs are still functional
    Verify ping is successful for ONUs not on this OLT     ${num_all_onus}    ${olt_device_id}
    #Verify that ping fails for the ONUs where the OLT has been rebooted
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[0]    sn
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    # Check OLT state of the rebooted OLT
    ${olt_serial_number}=    Get From Dictionary    ${list_olts}[0]    sn
    ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[0]    sship
    ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
    # Wait for the OLT to come back up
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s
    ...    Check Remote System Reachability    True    ${olt_ssh_ip}
    # Check OLT states
    Wait Until Keyword Succeeds    360s    5s
    ...    Validate OLT Device    ENABLED    ACTIVE
    ...    REACHABLE    ${olt_serial_number}
    # Waiting extra time for the ONUs to come up
    Sleep    60s
    #Check after reboot that ONUs are active, authenticated/DHCP/pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in ONOS    ${of_id}
        ${suppressaddsubscriber}=    Set Variable If    '${J}'=='0'    False    True
        Perform Sanity Test Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}   ${onu_count}
        ...    ${suppressaddsubscriber}
    END


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #power_switch.robot needs it to support different vendor's power switch
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

Clear All Devices Then Perform Setup And Sanity
    [Documentation]    Remove any devices from VOLTHA and Verify in ONOS
    ...    Create New Device through Setup and Perform Sanity
    # Remove all devices from voltha and onos
    Run Keyword and Ignore Error    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Perform Sanity Test

Teardown Suite
    [Documentation]    Clean up ONOS SSH connections
    Close All ONOS SSH Connections
    Run Keyword If    ${has_dataplane}    Clean Up All Nodes
