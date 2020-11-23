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
Documentation     This test raises alarms using bbsimctl and verifies them using voltctl
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
${timeout}        60s
${long_timeout}    420s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${setup_device}    True
${teardown_device}    True
${VOLTCTL_NAMESPACE}      default
${BBSIMCTL_NAMESPACE}      voltha
${VOLTCTL_POD_NAME}    voltctl
${BBSIMCTL_POD_NAME}    bbsim

*** Test Cases ***
Ensure required pods Running
    [Documentation]    Ensure the bbsim and voltctl pods are in Running state
    [Tags]    active
    Validate Pod Status    ${BBSIMCTL_POD_NAME}    ${BBSIMCTL_NAMESPACE}    Running
    Validate Pod Status    ${VOLTCTL_POD_NAME}    ${VOLTCTL_NAMESPACE}     Running

ONU Discovery
    [Documentation]    Discover lists of ONUS, their Serial Numbers and device id, and pick one for subsequent tests
    [Tags]    active
    #build onu sn list
    ${List_ONU_Serial}    Create List
    Set Suite Variable    ${List_ONU_Serial}
    Build ONU SN List    ${List_ONU_Serial}
    Log    ${List_ONU_Serial}
    #validate onu states
    Wait Until Keyword Succeeds    ${long_timeout}    20s
    ...    Validate ONU Devices    ENABLED    ACTIVE    REACHABLE    ${List_ONU_Serial}
    # Pick an ONU to use for subsequent test cases
    ${onu_sn}    Set Variable    ${List_ONU_Serial}[0]
    Set Suite Variable    ${onu_sn}
    ${onu_id}    Get Device ID From SN    ${onu_sn}
    Set Suite Variable    ${onu_id}
    ${parent_id}    Get Parent ID From Device ID     ${onu_id}
    Set Suite Variable    ${parent_id}

Test RaiseDriftOfWindowAlarm
    [Documentation]    Raise Drift Of Window Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_DRIFT_OF_WINDOW
    ...     ${onu_sn}    ONU_DRIFT_OF_WINDOW_RAISE_EVENT
    # Note: PON is the zero value of the subCategory field, and causes it to be not present
    Verify Header   ${header}    Voltha.openolt.ONU_DRIFT_OF_WINDOW\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_DRIFT_OF_WINDOW_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearDriftOfWindowAlarm
    [Documentation]    Clear Drift Of Window Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_DRIFT_OF_WINDOW
    ...     ${onu_sn}    ONU_DRIFT_OF_WINDOW_CLEAR_EVENT
    # Note: PON is the zero value of the subCategory field, and causes it to be not present
    Verify Header   ${header}    Voltha.openolt.ONU_DRIFT_OF_WINDOW\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_DRIFT_OF_WINDOW_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseDyingGaspAlarm
    [Documentation]    Raise Dying Gasp Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    DYING_GASP
    ...     ${onu_sn}    ONU_DYING_GASP_EVENT
    # Note: PON is the zero value of the subCategory field, and causes it to be not present
    Verify Header   ${header}    Voltha.openolt.ONU_DYING\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_DYING_GASP_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseLopcMissAlarm
    [Documentation]    Raise LOPC_MISS Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_ALARM_LOPC_MISS
    ...     ${onu_sn}    ONU_LOPC_MISS_RAISE_EVENT
    # Note: PON is the zero value of the subCategory field, and causes it to be not present
    Verify Header   ${header}    Voltha.openolt.ONU_LOPC_MISS\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOPC_MISS_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLopcMissAlarm
    [Documentation]    Clear LOPC_MISS Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_ALARM_LOPC_MISS
    ...     ${onu_sn}    ONU_LOPC_MISS_CLEAR_EVENT
    # Note: PON is the zero value of the subCategory field, and causes it to be not present
    Verify Header   ${header}    Voltha.openolt.ONU_LOPC_MISS\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOPC_MISS_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseLopcMicErrorAlarm
    [Documentation]    Raise LOPC_MISS Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_ALARM_LOPC_MIC_ERROR
    ...     ${onu_sn}    ONU_LOPC_MIC_ERROR_RAISE_EVENT
    # Note: PON is the zero value of the subCategory field, and causes it to be not present
    Verify Header   ${header}    Voltha.openolt.ONU_LOPC_MIC_ERROR\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOPC_MIC_ERROR_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLopcMicErrorAlarm
    [Documentation]    Clear LOPC_MISS Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_ALARM_LOPC_MIC_ERROR
    ...     ${onu_sn}    ONU_LOPC_MIC_ERROR_CLEAR_EVENT
    # Note: PON is the zero value of the subCategory field, and causes it to be not present
    Verify Header   ${header}    Voltha.openolt.ONU_LOPC_MIC_ERROR\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOPC_MIC_ERROR_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseLossOfBurstAlarm
    [Documentation]    Raise Loss Of Burst Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_ALARM_LOB
    ...     ${onu_sn}    ONU_LOSS_OF_BURST_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_BURST\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_BURST_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLossOfBurstAlarm
    [Documentation]    Clear Loss Of Burst Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}     Clear Onu Alarm And Get Event     ONU_ALARM_LOB
    ...    ${onu_sn}    ONU_LOSS_OF_BURST_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_BURST\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_BURST_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseLossOfFrameAlarm
    [Documentation]    Raise Loss Of Frame Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event     ONU_ALARM_LOFI
    ...     ${onu_sn}    ONU_LOSS_OF_FRAME_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_FRAME\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_FRAME_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLossOfFrameAlarm
    [Documentation]    Clear Loss Of Frame Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}     Clear Onu Alarm And Get Event      ONU_ALARM_LOFI
    ...    ${onu_sn}    ONU_LOSS_OF_FRAME_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_FRAME\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_FRAME_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseLossOfKeySyncFailureAlarm
    [Documentation]    Raise Loss Of Key Sync Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_LOSS_OF_KEY_SYNC_FAILURE
    ...     ${onu_sn}    ONU_LOSS_OF_KEY_SYNC_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_KEY_SYNC\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_KEY_SYNC_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLossOfKeySyncFailureAlarm
    [Documentation]    Clear Loss Of Key Sync Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_LOSS_OF_KEY_SYNC_FAILURE
    ...     ${onu_sn}    ONU_LOSS_OF_KEY_SYNC_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_KEY_SYNC\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_KEY_SYNC_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseLossOfOmciChannelAlarm
    [Documentation]    Raise Loss Of Omci Channel Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_LOSS_OF_OMCI_CHANNEL
    ...     ${onu_sn}    ONU_LOSS_OF_OMCI_CHANNEL_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_OMCI_CHANNEL\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_OMCI_CHANNEL_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLossOfOmciChannelAlarm
    [Documentation]    Clear Loss Of Omci Channel Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_LOSS_OF_OMCI_CHANNEL
    ...     ${onu_sn}    ONU_LOSS_OF_OMCI_CHANNEL_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_OMCI_CHANNEL\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_OMCI_CHANNEL_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseLossOfPloamAlarm
    [Documentation]    Raise Loss Of Ploam Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_ALARM_LOAMI
    ...     ${onu_sn}    ONU_LOSS_OF_PLOAM_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_PLOAM\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_PLOAM_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLossOfPloamAlarm
    [Documentation]    Clear Loss Of Ploam Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_ALARM_LOAMI
    ...     ${onu_sn}    ONU_LOSS_OF_PLOAM_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_PLOAM\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_PLOAM_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

# NOTE: ONU_ALARM_LOS a bit touchy as it seems to be automatically suppressed if
#   multiples are sent in a row. It seems like the bbsim state machine is interacting
#   with alarms, sometimes causing an ONU_ALARM_LOS to be sent, which then causes
#   this test to be a duplicate, which in turn is suppressed and fails. So what we
#   do is issue a CLEAR right before the RAISE.
Test RaiseLossOfSignalAlarm
    [Documentation]    Raise Loss Of Signal Alarm and verify event received
    [Tags]    active
    Clear Onu Alarm    ONU_ALARM_LOS    ${onu_sn}
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_ALARM_LOS
    ...     ${onu_sn}    ONU_LOSS_OF_SIGNAL_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_SIGNAL\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_SIGNAL_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearLossOfSignalAlarm
    [Documentation]    Clear Loss Of Signal Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_ALARM_LOS
    ...     ${onu_sn}    ONU_LOSS_OF_SIGNAL_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_SIGNAL\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_SIGNAL_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaisePonLossOfSignalAlarm
    [Documentation]    Raise Loss Of Signal Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Olt Alarm And Get Event    OLT_PON_LOS
    ...     0    OLT_LOSS_OF_SIGNAL_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.OLT_LOSS_OF_SIGNAL\.(\\d+)    OLT
    Should Be Equal    ${deviceEvent}[deviceEventName]    OLT_LOSS_OF_SIGNAL_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearPonLossOfSignalAlarm
    [Documentation]    Clear Loss Of Signal Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Olt Alarm And Get Event    OLT_PON_LOS
    ...     0    OLT_LOSS_OF_SIGNAL_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.OLT_LOSS_OF_SIGNAL\.(\\d+)    OLT
    Should Be Equal    ${deviceEvent}[deviceEventName]    OLT_LOSS_OF_SIGNAL_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseProcessingErrorAlarm
    # Not Implemented
    [Documentation]    Raise Processing Error Alarm and verify event received
    [Tags]    not-active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_PROCESSING_ERROR
    ...     ${onu_sn}    ONU_PROCESSING_ERROR_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_PROCESSING_ERROR\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_PROCESSING_ERROR_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearProcessingErrorAlarm
    # Not Implemented
    [Documentation]    Clear Processing Error Alarm and verify event received
    [Tags]    not-active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_PROCESSING_ERROR
    ...     ${onu_sn}    ONU_PROCESSING_ERROR_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_PROCESSING_ERROR\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_PROCESSING_ERROR_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseSignalDegradeAlarm
    [Documentation]    Raise Signal Degrade Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_SIGNAL_DEGRADE
    ...     ${onu_sn}    ONU_SIGNAL_DEGRADE_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_SIGNAL_DEGRADE\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_SIGNAL_DEGRADE_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearSignalDegradeAlarm
    [Documentation]    Clear Signal Degrade Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_SIGNAL_DEGRADE
    ...     ${onu_sn}    ONU_SIGNAL_DEGRADE_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_SIGNAL_DEGRADE\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_SIGNAL_DEGRADE_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseSignalsFailureAlarm
    [Documentation]    Raise Signals Fail Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_SIGNALS_FAILURE
    ...     ${onu_sn}    ONU_SIGNALS_FAIL_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_SIGNALS_FAIL\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_SIGNALS_FAIL_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearSignalsFailureAlarm
    [Documentation]    Clear Signals Fail Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_SIGNALS_FAILURE
    ...     ${onu_sn}    ONU_SIGNALS_FAIL_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_SIGNALS_FAIL\.(\\d+)    ${EMPTY}
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_SIGNALS_FAIL_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseStartupFailureAlarm
    # Not Implemented
    [Documentation]    Raise Startup Failure Alarm and verify event received
    [Tags]    not-active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_STARTUP_FAILURE
    ...     ${onu_sn}    ONU_STARTUP_FAILURE_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_STARTUP_FAILURE\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_STARTUP_FAILURE_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearStartupFailureAlarm
    # Not Implemented
    [Documentation]    Clear Startup Failure Alarm and verify event received
    [Tags]    not-active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_STARTUP_FAILURE
    ...     ${onu_sn}    ONU_STARTUP_FAILURE_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_STARTUP_FAILURE\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_STARTUP_FAILURE_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test RaiseTransmissionInterferenceAlarm
    # Not Implemented
    [Documentation]    Raise Transmission Interference Alarm and verify event received
    [Tags]    not-active
    ${header}    ${deviceEvent}    Raise Onu Alarm And Get Event    ONU_TRANSMISSION_INTERFERENCE_WARNING
    ...     ${onu_sn}    ONU_TRANSMISSION_INTERFERENCE_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_TRANSMISSION_INTERFERENCE\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_TRANSMISSION_INTERFERENCE_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

Test ClearTransmissionInterferenceAlarm
    # Not Implemented
    [Documentation]    Clear Transmission Interference Alarm and verify event received
    [Tags]    not-active
    ${header}    ${deviceEvent}    Clear Onu Alarm And Get Event    ONU_TRANSMISSION_INTERFERENCE_WARNING
    ...     ${onu_sn}    ONU_TRANSMISSION_INTERFERENCE_CLEAR_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_TRANSMISSION_INTERFERENCE\.(\\d+)    ONU
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_TRANSMISSION_INTERFERENCE_CLEAR_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    # Ensure the voltctl pod is deployed and running
    Apply Kubernetes Resources    ./voltctl.yaml    ${VOLTCTL_NAMESPACE}
    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate Pod Status    ${VOLTCTL_POD_NAME}    ${VOLTCTL_NAMESPACE}     Running
    # Call Setup keyword in utils library to create and enable device
    Run Keyword If    ${setup_device}    Setup

Teardown Suite
    [Documentation]    Clean up devices if desired
    ...    kills processes and cleans up interfaces on src+dst servers
    Get ONOS Status    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${teardown_device}    Delete Device and Verify
    Run Keyword If    ${teardown_device}    Test Empty Device List
    Run Keyword If    ${teardown_device}    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    ...    device-remove ${of_id}

# Onu Alarms

Raise Onu Alarm And Get Event
    [Documentation]    Raise an Alarm and return event
    [Arguments]    ${name}    ${sn}    ${deviceEventName}
    ${since}    Get Current Time
    Raise Onu Alarm    ${name}    ${sn}
    ${header}    ${deviceEvent}    Get Device Event    ${deviceEventName}    ${since}
    ${LastEventPostTimestamp}    Set Variable     ${since}
    Set Suite Variable     ${LastEventPostTimestamp}
    [return]    ${header}    ${deviceEvent}

Clear Onu Alarm And Get Event
    [Documentation]    Clear an Alarm and return event
    [Arguments]    ${name}    ${sn}    ${deviceEventName}
    ${since}    Get Current Time
    Clear Onu Alarm    ${name}    ${sn}
    ${header}    ${deviceEvent}    Get Device Event    ${deviceEventName}    ${since}
    ${LastEventPostTimestamp}    Set Variable     ${since}
    Set Suite Variable     ${LastEventPostTimestamp}
    [return]    ${header}    ${deviceEvent}

Raise Onu Alarm
    [Documentation]    Raise an Alarm
    [Arguments]    ${name}    ${sn}
    ${raiseOutput}    Exec Pod    ${BBSIMCTL_NAMESPACE}     ${BBSIMCTL_POD_NAME}
    ...    bbsimctl onu alarms raise ${name} ${sn}
    Should Contain    ${raiseOutput}    Alarm Indication Sent

Clear Onu Alarm
    [Documentation]    Raise an Alarm
    [Arguments]    ${name}    ${sn}
    ${raiseOutput}    Exec Pod    ${BBSIMCTL_NAMESPACE}     ${BBSIMCTL_POD_NAME}
    ...    bbsimctl onu alarms clear ${name} ${sn}
    Should Contain    ${raiseOutput}    Alarm Indication Sent

# Olt Alarms

Raise Olt Alarm And Get Event
    [Documentation]    Raise an Alarm and return event
    [Arguments]    ${name}    ${intf_id}    ${deviceEventName}
    ${since}    Get Current Time
    Raise Olt Alarm    ${name}    ${intf_id}
    ${header}    ${deviceEvent}    Get Device Event    ${deviceEventName}    ${since}
    ${LastEventPostTimestamp}    Set Variable     ${since}
    Set Suite Variable     ${LastEventPostTimestamp}
    [return]    ${header}    ${deviceEvent}

Clear Olt Alarm And Get Event
    [Documentation]    Clear an Alarm and return event
    [Arguments]    ${name}    ${intf_id}    ${deviceEventName}
    ${since}    Get Current Time
    Clear Olt Alarm    ${name}    ${intf_id}
    ${header}    ${deviceEvent}    Get Device Event    ${deviceEventName}    ${since}
    ${LastEventPostTimestamp}    Set Variable     ${since}
    Set Suite Variable     ${LastEventPostTimestamp}
    [return]    ${header}    ${deviceEvent}

Raise Olt Alarm
    [Documentation]    Raise an Alarm
    [Arguments]    ${name}    ${intf_id}
    ${raiseOutput}    Exec Pod    ${BBSIMCTL_NAMESPACE}     ${BBSIMCTL_POD_NAME}
    ...    bbsimctl olt alarms raise ${name} ${intf_id}
    Should Contain    ${raiseOutput}    Alarm Indication Sent

Clear Olt Alarm
    [Documentation]    Raise an Alarm
    [Arguments]    ${name}    ${intf_id}
    ${raiseOutput}    Exec Pod    ${BBSIMCTL_NAMESPACE}     ${BBSIMCTL_POD_NAME}
    ...    bbsimctl olt alarms clear ${name} ${intf_id}
    Should Contain    ${raiseOutput}    Alarm Indication Sent

Get Device Event
    [Documentation]    Get the most recent alarm event from voltha.events
    [Arguments]    ${deviceEventName}    ${since}
    ${output}    ${raiseErr}    Exec Pod Separate Stderr   ${VOLTCTL_NAMESPACE}     ${VOLTCTL_POD_NAME}
    ...    voltctl event listen --show-body -t 1 -o json -f Titles=${deviceEventName}
    ${json}    To Json    ${output}
    ${count}    Get Length    ${json}
    # If there is more than one event (which could happen if we quickly do a raise and a clear),
    # then return the most recent one.
    Should Be Larger Than   ${count}    0
    ${lastIndex}    Evaluate    ${count}-1
    ${lastItem}    Set Variable    ${json}[${lastIndex}]
    ${header}    Set Variable    ${lastItem}[header]
    ${deviceEvent}    Set Variable   ${lastItem}[deviceEvent]
    Log    ${header}
    Log    ${deviceEvent}
    [return]    ${header}    ${deviceEvent}

Verify Header
    [Documentation]    Verify that a DeviceEvent's header is sane and the id matches regex
    [Arguments]    ${header}    ${id}    ${subCategory}
    ${headerSubCategory}    Evaluate    $header.get("subCategory", "")
    Should Be Equal   ${headerSubCategory}    ${subCategory}
    Should Be Equal   ${header}[type]    DEVICE_EVENT
    Should Match Regexp    ${header}[id]    ${id}
    # TODO Timestamps are now RFC3339 date strings. Add Verification
    ${reportedTs}    Set Variable    ${header}[reportedTs]
    ${raisedTs}    Set Variable    ${header}[raisedTs]
    Should Be Newer Than Or Equal To    ${reportedTs}    ${LastEventPostTimestamp}
    Should Be Newer Than Or Equal To    ${raisedTs}    ${LastEventPostTimestamp}
