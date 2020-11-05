# Copyright 2017 - present Open Networking Foundation
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
# FIXME Can we use the same test against BBSim and Hardware?

*** Settings ***
Documentation     Test various end-to-end scenarios
Suite Setup       Common Test Suite Setup
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

*** Variables ***
${POD_NAME}       flex-ocp-cord
${KUBERNETES_CONF}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_CONFIGS_DIR}    ~/pod-configs/kubernetes-configs
#${KUBERNETES_CONFIGS_DIR}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.conf
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${NAMESPACE}      voltha
# For below variable value, using deployment name as using grep for
# parsing radius pod name, we can also use full radius pod name
${RESTART_POD_NAME}    radius
${timeout}        360s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    False
${scripts}        ../../scripts
${workflow}    ATT

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Adding the same OLT before and after enabling the device
    [Documentation]    Create OLT, Create the same OLT again and Check for the Error message
    ...                VOL-2405  VOL-2406
    [Tags]    AddSameOLT   functional    released
    [Setup]    Start Logging    AddSameOLT
    [Teardown]   Run Keywords     Collect Logs
    ...          AND              Stop Logging    AddSameOLT
    # Add OLT device
    #setup
    Delete All Devices and Verify
    Run Keyword and Ignore Error   Collect Logs
    # Wait for the OLT to be reachable
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_ip}=    Get From Dictionary    ${list_olts}[${I}]   ip
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        #${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s
        ...    Check Remote System Reachability    True    ${olt_ssh_ip}
        ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
        Set Suite Variable    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
        ...    ${olt_device_id}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${olt_ip}:${OLT_PORT}
        Should Not Be Equal As Integers    ${rc}    0
        Should Contain     ${output}     device is already pre-provisioned    ignore_case=True
        #Enable the created OLT device
        Enable Device    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${olt_ip}:${OLT_PORT}
        Should Not Be Equal As Integers    ${rc}    0
        Log    ${output}
        Should Contain     ${output}    device is already pre-provisioned    ignore_case=True
        Log    "This OLT is added already and enabled"
    END

Test Disable or Enable different device id which is not in the device list
    [Documentation]    Disable or Enable  a device id which is not listed in the voltctl device list
    ...    command and ensure that error message is shown.
    ...    VOL-2412-2413
    [Tags]    functional    DisableEnableInvalidDevice    released
    [Setup]    Start Logging    DisableInvalidDevice
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableInvalidDevice
    Run Keyword and Ignore Error   Collect Logs
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
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
    #Create a new fake device id
    ${fakeDeviceId}    Replace String Using Regexp          ${device_id}    \\d\\d     xx    count=1
    Log     ${fakeDeviceId}
    #Ensure that the new id created is not in the device id list
    List Should Not Contain Value    ${ids}    ${fakeDeviceId}
    #Disable fake device id
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${fakeDeviceId}
    Should Contain    ${output}     Error while disabling '${fakeDeviceId}'
    #Disable device for VOL-2413
    Disable Device    ${device_id}
    #Enable fake device id
    ${rc}  ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device enable ${fakeDeviceId}
    Should Contain    ${output}     Error while enabling '${fakeDeviceId}'

Check deletion of OLT/ONU before disabling
    [Documentation]    Try deleting OL/ONU before disabling and check error message
    ...    Assuming devices are already created, up and running fine; test1 or sanity was
    ...    executed where all the ONUs are authenticated/DHCP/pingable
    ...    VOL-2411
    #TODO: If this TC gets updated in future, To add support for DT workflow as well (refer JIRA: VOL-2945)
    [Tags]    functional    DeleteBeforeDisableCheck    notready
    [Setup]   Start Logging    DeleteBeforeDisableCheck
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DeleteBeforeDisableCheck
    #validate olt states
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_ip}=    Get From Dictionary    ${list_olts}[${I}]   ip
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        #${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...   REACHABLE    ${olt_serial_number}
        ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
        Log    ${output}
        Should Contain     ${output}     expected-admin-state:DISABLED
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
    END
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
	${src}=    Set Variable    ${hosts.src[${I}]}
	${dst}=    Set Variable    ${hosts.dst[${I}]}
	${onu_device_id}=    Get Device ID From SN    ${src['onu']}
	Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
	...    ENABLED    ACTIVE    REACHABLE
	...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
	${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${onu_device_id}
	Log    ${output}
	Should Contain     ${output}     expected-admin-state:DISABLED
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
    END

Check disabling of pre-provisioned OLT before enabling
    [Documentation]    Create OLT, disable same OLT, check error message and validates ONU
    ...                VOL-2414
    [Tags]    functional    DisablePreprovisionedOLTCheck
    [Setup]   Run Keywords    Start Logging    DisablePreprovisionedOLTCheck
    ...       AND             Delete All Devices and Verify
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisablePreprovisionedOLTCheck
    Sleep    180s
    Run Keyword and Ignore Error    Collect Logs
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_ip}=    Get From Dictionary    ${list_olts}[${I}]   ip
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        #${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        #create/preprovision device
        ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
        Set Suite Variable    ${olt_device_id}
        #validate olt states
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN
        ...    UNKNOWN    ${olt_device_id}
        #Try disabling pre-provisioned OLT
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
        Should Not Be Equal As Integers    ${rc}    0
        Log    ${output}
        Should Contain     ${output}     invalid-admin-state:PREPROVISIONED
        #Enable OLT
        Enable Device    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        Set Suite Variable    ${logical_id}
    END
    ${onu_reason}=    Set Variable If    '${workflow}' == 'DT'    initial-mib-downloaded    omci-flows-pushed
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
	${src}=    Set Variable    ${hosts.src[${I}]}
	${dst}=    Set Variable    ${hosts.dst[${I}]}
	Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
	...    ENABLED    ACTIVE    REACHABLE
	...    ${src['onu']}    onu=True    onu_reason=${onu_reason}
    END

Disable and Delete the logical device directly
    [Documentation]    Disable and delete the logical device directly is not possible
    ...    since it is allowed only through OLT device deletion.
    ...    VOL-2418
    [Tags]    functional     DisableDelete_LogicalDevice
    [Setup]   Run Keywords    Start Logging    DisableDelete_LogicalDevice
    ...       AND             Delete All Devices and Verify
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableDelete_LogicalDevice
    Run Keyword If    ${has_dataplane}    Sleep    180s
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_ip}=    Get From Dictionary    ${list_olts}[${I}]   ip
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        #${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        #create/preprovision OLT device
        ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
        Set Suite Variable    ${olt_device_id}
        #validate olt states
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN
        ...    UNKNOWN    ${olt_device_id}
        #Enable the created OLT device
        Enable Device    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${olt_serial_number}
        #Check whether logical devices are also created
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice list
        Should Be Equal As Integers    ${rc}    0
        Log    ${output}
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        Should Not Be Empty    ${logical_id}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice disable ${logical_id}
        Should Not Be Equal As Integers    ${rc}    0
        Log    ${output}
        Should Contain     '${output}'     Unknown command
        ${rc}    ${output1}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice delete ${logical_id}
        Should Not Be Equal As Integers    ${rc}    0
        Log    ${output1}
        Should Contain     '${output1}'     Unknown command
    END

Check logical device creation and deletion
    [Documentation]    Deletes all devices, checks logical device, creates devices again and checks
    ...    logical device, flows, ports
    ...    VOL-2416 VOL-2417
    [Tags]    functional    LogicalDeviceCheck
    [Setup]   Start Logging    LogicalDeviceCheck
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    LogicalDeviceCheck
    Delete All Devices and Verify
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_user}=    Get From Dictionary    ${list_olts}[${I}]    user
        ${olt_pass}=    Get From Dictionary    ${list_olts}[${I}]    pass
        ${olt_ssh_ip}=    Get From Dictionary    ${list_olts}[${I}]   sship
        ${olt_ip}=    Get From Dictionary    ${list_olts}[${I}]   ip
        ${olt_serial_number}=    Get From Dictionary    ${list_olts}[${I}]    sn
        #${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        Should Be Empty    ${logical_id}
        Run Keyword If    ${has_dataplane}    Sleep    180s
        ...    ELSE   Sleep    10s
        ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
        Set Suite Variable    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN
        ...    UNKNOWN    ${olt_device_id}
        Enable Device    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        Should Not Be Empty    ${logical_id}
        ${rc}    ${output}=    Run and Return Rc and Output
        ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice list
        Should Be Equal As Integers    ${rc}    0
        Log    ${output}
        Should Contain     ${output}    ${olt_device_id}
        Set Suite Variable    ${logical_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Logical Device Ports    ${logical_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate Logical Device Flows    ${logical_id}
        Run Keyword and Ignore Error    Collect Logs
    END

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup

Teardown Suite
    [Documentation]    Teardown suite
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    #Restore all ONUs
#    Run Keyword If    ${has_dataplane}    RestoreONUs    ${num_onus}
