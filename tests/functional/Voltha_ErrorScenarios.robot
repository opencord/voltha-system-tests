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
#Suite Teardown    Teardown Suite
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
${timeout}        90s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    False
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Adding the same OLT before and after enabling the device
    [Documentation]    Create OLT, Create the same OLT again and Check for the Error message
    [Tags]    VOL-2405   VOL-2406   AddSameOLT   functional
    [Setup]    Run Keywords    Announce Message    START TEST AddSameOLT
    ...        AND             Start Logging    AddSameOLT
    [Teardown]   Run Keywords     Collect Logs
    ...          AND              Stop Logging    AddSameOLT
    ...          AND              Announce Message    END TEST AddSameOLT
    Run Keyword If    ${has_dataplane}    Delete Device and Verify
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    ${timeout}    Set Variable    180
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    ...    ${EMPTY}    ${olt_device_id}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${olt_ip}:${OLT_PORT}
    Should Not Be Equal As Integers    ${rc}    0
    Should Contain     ${output}     Device is already pre-provisioned
    #Enable the created OLT device
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl device create -t openolt -H ${olt_ip}:${OLT_PORT}
    Should Not Be Equal As Integers    ${rc}    0
    Log    ${output}
    Should Contain     ${output}    Device is already pre-provisioned
    Log    "This OLT is added already and enabled"

Test Disable or Enable different device id which is not in the device list
    [Documentation]    Disable or Enable  a device id which is not listed in the voltctl device list
    ...    command and ensure that error message is shown.
    [Tags]    functional    DisableEnableInvalidDevice    VOL-2412-2413
    [Setup]    Run Keywords    Announce Message    START TEST DisableInvalidDevice
    ...        AND             Start Logging    DisableInvalidDevice
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableInvalidDevice
    ...           AND             Announce Message    END TEST DisableInvalidDevice
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
    [Tags]    VOL-2411    DeleteBeforeDisableCheck    notready
    [Setup]   Run Keywords    Announce Message    START TEST DeleteBeforeDisableCheck
    ...       AND             Start Logging    DeleteBeforeDisableCheck
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DeleteBeforeDisableCheck
    ...           AND             Announce Message    END TEST DeleteBeforeDisableCheck
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device delete ${olt_device_id}
    Log    ${output}
    Should Contain     ${output}     expected-admin-state:DISABLED
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE    ${olt_serial_number}
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
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
    Run Keyword and Ignore Error   Collect Logs

Check disabling of pre-provisioned OLT before enabling
    [Documentation]    Create OLT, disable same OLT, check error message and validates ONU
    [Tags]    VOL-2414    DisablePreprovisionedOLTCheck    notready
    [Setup]   Run Keywords    Announce Message    START TEST DisablePreprovisionedOLTCheck
    ...       AND             Start Logging    DisablePreprovisionedOLTCheck
    ...       AND             Delete Device and Verify
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisablePreprovisionedOLTCheck
    ...           AND             Announce Message    END TEST DisablePreprovisionedOLTCheck
    Run Keyword If    ${has_dataplane}    Sleep    180s
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    ...    ${EMPTY}    ${olt_device_id}
    #Try disabling pre-provisioned OLT
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device disable ${olt_device_id}
    Should Be Equal As Integers    ${rc}    0
    Log    ${output}
    Should Contain     ${output}     invalid-admin-state:PREPROVISIONED
    #Enable OLT
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Set Suite Variable    ${logical_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
	${src}=    Set Variable    ${hosts.src[${I}]}
	${dst}=    Set Variable    ${hosts.dst[${I}]}
	Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
	...    ENABLED    ACTIVE    REACHABLE
	...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
    END
    Run Keyword and Ignore Error   Collect Logs

Disable and Delete the logical device directly
    [Documentation]    Disable and delete the logical device directly is not possible
    ...    since it is allowed only through OLT device deletion.
    [Tags]    VOL-2418     DisableDelete_LogicalDevice    notready
    [Setup]   Run Keywords    Announce Message    START TEST DisableDelete_LogicalDevice
    ...       AND             Start Logging    DisableDelete_LogicalDevice
    ...       AND             Delete Device and Verify
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    DisableDelete_LogicalDevice
    ...           AND             Announce Message    END TEST DisableDelete_LogicalDevice
    Run Keyword If    ${has_dataplane}    Sleep    180s
    #create/preprovision OLT device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    ...    ${EMPTY}    ${olt_device_id}
    #Enable the created OLT device
    Enable Device    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
    ...    ${olt_serial_number}
    #Check whether logical devices are also created
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice list
    Should Be Equal As Integers    ${rc}    0
    Log    ${output}
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Should Not Be Empty    ${logical_id}
    ${rc}    ${output}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice disable ${logical_id}
    Should Be Equal As Integers    ${rc}    0
    Log    ${output}
    Should Contain     '${output}'     Unknown command
    ${rc}    ${output1}=    Run and Return Rc and Output
    ...    ${VOLTCTL_CONFIG}; voltctl logicaldevice delete ${logical_id}
    Should Be Equal As Integers    ${rc}    0
    Log    ${output1}
    Should Contain     '${output1}'     Unknown command

Check logical device creation and deletion
    [Documentation]    Deletes all devices, checks logical device, creates devices again and checks
    ...    logical device, flows, ports
    [Tags]    VOL-2416    VOL-2417    LogicalDeviceCheck    notready
    [Setup]   Run Keywords    Announce Message    START TEST LogicalDeviceCheck
    ...       AND             Start Logging    LogicalDeviceCheck
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    LogicalDeviceCheck
    ...           AND             Announce Message    END TEST LogicalDeviceCheck
    Delete Device and Verify
    ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
    Should Be Empty    ${logical_id}
    Run Keyword If    ${has_dataplane}    Sleep    180s
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    ...    ${EMPTY}    ${olt_device_id}
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
