# Copyright 2022 - present Open Networking Foundation
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
Suite Setup      Setup Suite
Test Setup        Setup
Test Teardown    Teardown
Suite Teardown    Teardown Suite
Library           XML
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Resource          ../../libraries/bbf_adapter_utilities.robot
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
${KUBERNETES_YAML}    ${KUBERNETES_CONFIGS_DIR}/${POD_NAME}.yml
${HELM_CHARTS_DIR}    ~/helm-charts
${VOLTHA_POD_NUM}    8
${NAMESPACE}      voltha
${INFRA_NAMESPACE}      default
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    False
${teardown_device}    True
${scripts}        ../../scripts

# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

# Flag specific to Soak Jobs
${SOAK_TEST}    False
${bbsim_port}    50060

#Suppress the subscribe phase
${supress_add_subscriber}     False

#Enable or Disable the MacLearning verifier for MacLearning ONOS APP
${maclearningenabled}   False   #Not yet used but it is a placeholder

*** Test Cases ***
BBF Adapter Aggregation Test
    [Documentation]     Do a runtime test enabling all the device
    ...     and verify if VOLTHA and BBF have the same view,
    ...     with the correct translation, of the network
    [Tags]    sanityBbfAdapter
    [Setup]    Start Logging    sanityBbfAdapter
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    sanityBbfAdapter
    Run Keyword     Setup    ${SOAK_TEST}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Get BBF Device Aggregation  ${NAMESPACE}  ${CURDIR}/data.xml  ${scripts}
    Log     ${supress_add_subscriber}
    Perform Sanity Test of BBFadapter Aggregation       ./data.xml      ${supress_add_subscriber}
    Teardown Suite

Test Disable and Enable ONU for BBF
    [Documentation]    Disable ONUs from the BBF Adapter (PlaceHolder with VOLTHA)
    ...     Verify all the states in voltha and in the BBF Adapter (like a compare).
    ...     Enable the ONUs from the BBF adapter, verify the enable states in voltha
    ...     and in BBF Adapter (like a compare).
    ...     It is also possible to verify a connectivity, with a no block test.
    [Tags]    bbfAdapterFunctionality   disableEnableONUBBF
    [Setup]    Start Logging    disableEnableONUBBF
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    disableEnableONUBBF
    # Create a single Setup for Multiple Test Case
    Run Keyword     Setup    ${SOAK_TEST}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    # Disable, verify state, Enable and verify stato for each ONU
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Subscribe the ONU if requested for the tests
        Run Keyword If    '${supress_add_subscriber}' == 'False'    Wait Until Keyword Succeeds    ${timeout}    2s
        ...     Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...     ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        # Disbale the device (actually with voltha in future with BBF Adapter)
        Disable Device    ${onu_device_id}
        Disable Device in BBF    ${onu_device_id}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Define some states that the ONU reason can be
        ${onu_reasons}=  Create List     omci-flows-deleted
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    omci-admin-lock
        Log     ${onu_reasons}
        # Verify in Voltha the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=${onu_reasons}
        # Verify in the BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Onu in BBF     DISABLED     UNKNOWN
        ...    REACHABLE    ${src['onu']}   ${onu_reasons}
        # Verify if the disabling of the ONU desable also the UNI port
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        # Verify if there are not connectivity to the ONU
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        # Enable the device (actually with voltha in future with BBF Adapter)
        Enable Device    ${onu_device_id}
        Enable Device in BBF    ${onu_device_id}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Define some states that the ONU reason can be
        ${onu_reasons}=  Create List     omci-flows-pushed
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    onu-reenabled
        Log     ${onu_reasons}
        # Verify in the Voltha the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=${onu_reasons}
        # Verify in the BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Onu in BBF     ENABLED     ACTIVE
        ...    REACHABLE    ${src['onu']}   ${onu_reasons}
        # Verify if the disabling of the ONU desable also the UNI port
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        # Verify if there are not connectivity to the ONU
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

Test Disable and Enable OLT for BBF
    [Documentation]    Disable OLTs from the BBF Adapter (Placeholder with Voltha).
    ...     Verify the disable states of OLTs in Voltha and in the BBF Adapter (like a compare).
    ...     Enable the OLTs from the BBF adapter, verify the states in voltha
    ...     and in BBF Adapter (like a compare).
    ...     It is also possible to verify a connectivity, with a no block test.
    [Tags]    bbfAdapterFunctionality   disableEnableOLTBBF
    [Setup]    Start Logging    disableEnableOLTBBF
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    disableEnableOLTBBF
    # Disable each OLT and Validate it state
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Get ofID From OLT List     ${olt_serial_number}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  ENABLED  ACTIVE  REACHABLE
        ...    ${olt_serial_number}  ${olt_device_id}
        # Disbale the device (actually with voltha in future with BBF Adapter)
        Disable Device      ${olt_device_id}
        Disable Device in BBF    ${olt_device_id}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
        ...    ${olt_serial_number}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  DISABLED  UNKNOWN  REACHABLE
        ...    ${olt_serial_number}  ${olt_device_id}
    END
    # Enable the OLT back and check OLT operstatus are back to "ACTIVE"
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        ${of_id}=    Get ofID From OLT List    ${olt_serial_number}
        # Enable the device (actually with voltha in future with BBF Adapter)
        Enable Device    ${olt_device_id}
        Enable Device in BBF  ${olt_device_id}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  ENABLED  ACTIVE  REACHABLE
        ...    ${olt_serial_number}  ${olt_device_id}
    END

Test Disable and Delete OLT for BBF
    [Documentation]    Disable OLTs from the BBF Adapter (PlaceHolder with Voltha)
    ...     Verify the disable state of the OLT in voltha and in the BBF Adapter,
    ...     Delete the OLTs from the BBF adapter, verify if it was done correctly in voltha
    ...     and in BBF Adapter.
    [Tags]    bbfAdapterFunctionality    disableEnableOLTBBF
    [Setup]    Start Logging    disableEnableOLTBBF
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    disableEnableOLTBBF
    # Disable and Validate OLT Device
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Disable Device    ${olt_device_id}
        Disable Device in BBF    ${olt_device_id}
        ${of_id}=    Get ofID From OLT List    ${olt_serial_number}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Retrive from BBF Adapter an Update XML that contain all the devices
        ALL DEVICES XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
        ...    ${olt_serial_number}
        Validate Olt Disabled in BBF  ${olt_serial_number}  ${olt_device_id}

        ${num_onus}=    Set Variable    ${list_olts}[${I}][onucount]
        # Validate ONUs
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate ONUs After OLT Disable
        ...    ${num_onus}    ${olt_serial_number}
        Validate ONUs After OLT Disable in BBF      ${olt_serial_number}
        # Delete the device (actually with voltha in future with BBF Adapter)
        Delete Device    ${olt_device_id}
        Delete Device in BBF    ${olt_device_id}
        # Retrive from BBF Adapter an Update XML that contain all the devices
        ALL DEVICES XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Check that the OLT are actually removed from the system
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed
        ...    ${olt_serial_number}
        # Check if the OLT has been removed from the system
        Validate Device Removed in BBF  ${olt_serial_number}
        # Validate if all the ONUS connected at the OLT revomed are also been removed in VOLTHA
        Run Keyword and Continue On Failure    Validate all ONUS for OLT Removed    ${num_all_onus}    ${hosts}
        ...    ${olt_serial_number}    ${timeout}
        # Validate if all the ONUS connected at the OLT revomed are also been removed in BBF Adapter
        Validate All Onus for OLT Removed in BBF  ${olt_serial_number}
        #Wait Until Keyword Succeeds    ${timeout}    5s
        #...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    END
    Teardown Suite

Test Delete and ReAdd OLT for BBF
    [Documentation]    Delete OLTs from the BBF Adapter (PlaceHolder with Voltha)
    ...     Verify if the OLT and ONUs connected was really delete in voltha and in the BBF Adapter.
    ...     Readd all the OLTs from the BBF adapter, verify the enable state in voltha
    ...     and in BBF Adapter and check the correct status after the readd.
    [Tags]    bbfAdapterFunctionality    DeleteReAddOLTBBF
    [Setup]    Start Logging    DeleteReAddOLTBBF
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DeleteReAddOLTBBF
    Run Keyword     Setup    ${SOAK_TEST}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        # Delete the device (actually with voltha in future with BBF Adapter)
        Delete Device    ${olt_device_id}
        Delete Device in BBF    ${olt_device_id}
        # Retrive from BBF Adapter an Update XML that contain all the devices
        ALL DEVICES XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Check if the OLT has been removed from the system
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device Removed      ${olt_serial_number}
        # Check if the OLT has been removed from the BBF Adapter
        Validate Device Removed in BBF  ${olt_serial_number}
        # Validate if all the ONUS connected at the OLT revomed are also been removed in VOLTHA
        Run Keyword and Continue On Failure    Validate all ONUS for OLT Removed    ${num_all_onus}    ${hosts}
        ...    ${olt_serial_number}    ${timeout}
        # Validate if all the ONUS connected at the OLT revomed are also been removed in BBF Adapter
        Validate all ONUS for OLT Removed in BBF  ${olt_serial_number}
        #Wait Until Keyword Succeeds    ${timeout}    5s
        #...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    END
    # Recreate the OLTs
    Run Keyword     Setup    ${SOAK_TEST}
    # Retrive from BBF Adapter an Update XML that contain the ONUs
    OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        # Verify in Voltha the State of the OLT
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  ENABLED  ACTIVE  REACHABLE
        ...    ${olt_serial_number}  ${olt_device_id}
    END
    Teardown Suite

Test Disable ONUs and OLT for BBF
    [Documentation]     Disable ONUs and OLTs, verify if the OLT and ONUs connected
    ...     was really disable in voltha and in the BBF Adapter.
    ...     Delete ONUs and OLTs, verify if the ONUs and OLT was really deleted
    ...     in voltha and BBF Adapter.
    [Tags]    bbfAdapterFunctionality    DisableONUOLTBBF
    [Setup]    Start Logging    DisableONUOLTBBF
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DisableONUOLTBBF
    Run Keyword     Setup    ${SOAK_TEST}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    # Define some states that the ONU reason can be
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}    ${src['uni_id']}
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${src['olt']}
        # Subscribe the ONU if requested for the tests
        Run Keyword If    '${supress_add_subscriber}' == 'False'    Wait Until Keyword Succeeds    ${timeout}    2s
        ...     Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...     ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        # Onu reasons selection
        @{onu_reasons}=  Create List     omci-flows-pushed
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    initial-mib-downloaded
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in the Voltha the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['onu']}    onu=True    onu_reason=${onu_reasons}
        # Verify in the BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Onu in BBF     ENABLED     ACTIVE
        ...    REACHABLE    ${src['onu']}   ${onu_reasons}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['olt']}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  ENABLED  ACTIVE  REACHABLE
        ...    ${src['olt']}  ${olt_device_id}
        # Disbale the device (actually with voltha in future with BBF Adapter)
        Disable Device    ${onu_device_id}
        Disable Device in BBF  ${onu_device_id}
        # Onu reasons selection
        ${onu_reasons}=  Create List     omci-flows-deleted
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    omci-admin-lock
        Log     ${onu_reasons}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in the Voltha the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['onu']}   ${onu_reasons}  onu=True
        # Verify in the BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Onu in BBF     DISABLED     UNKNOWN
        ...    REACHABLE    ${src['onu']}   ${onu_reasons}
        # Check if the OLT where the ONU is connected have the correct state
        # after the disbaling one ONU connected
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    ENABLED    ACTIVE
        ...    REACHABLE    ${src['olt']}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  ENABLED  ACTIVE  REACHABLE
        ...    ${src['olt']}  ${olt_device_id}
    END
    # Disable all OLTs and check if the state after disable are correct
    FOR   ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Disable Device    ${olt_device_id}
        Disable Device in BBF    ${olt_device_id}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    DISABLED    UNKNOWN    REACHABLE
        ...    ${olt_serial_number}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  DISABLED  UNKNOWN  REACHABLE
        ...     ${olt_serial_number}  ${olt_device_id}
    END

Delete Disabled ONUs and OLT for BBF
    [Documentation]   Continue of the before test.
    ...     Validate the Disble state of ONUs and Oltes,
    ...     Delete Disabled Onus and Disabled Olts and verify the correct
    ...     elimination of all devices from Voltha and BBF Adapter.
    [Tags]    bbfAdapterFunctionality    DeleteONUOLTBBF
    [Setup]    Start Logging    DeleteONUOLTBBF
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    DeleteONUOLTBBF
    # Validate ONUs states after OLT disable
    ${onu_reasons}=  Create List     stopping-openomci
    Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    stopping-openomci
    Log     ${onu_reasons}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${src['olt']}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in the Voltha the State of the ONU
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Device    DISABLED    DISCOVERED
        ...    UNREACHABLE    ${src['onu']}    ${onu_reasons}   onu=True
        # Verify in the BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Onu in BBF     DISABLED     DISCOVERED
        ...    UNREACHABLE    ${src['onu']}   ${onu_reasons}
        # Delete the device (actually with voltha in future with BBF Adapter)
        Delete Device    ${onu_device_id}
        Delete Device in BBF    ${onu_device_id}
        # Retrive from BBF Adapter an Update XML that contain all the devices
        ALL DEVICES XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        Validate Device Removed in BBF  ${src['onu']}
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        OLT XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify in Voltha the State of the OLT
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    DISABLED    UNKNOWN
        ...    REACHABLE    ${src['olt']}
        # Verify in BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Olt in BBF  DISABLED  UNKNOWN  REACHABLE
        ...    ${src['olt']}  ${olt_device_id}
    END
    # Delete all OLTs
    # Delete All Devices and Verify
    FOR    ${I}    IN RANGE    0    ${olt_count}
        ${olt_serial_number}=    Get From Dictionary    ${olt_ids}[${I}]    sn
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        # Delete the device (actually with voltha in future with BBF Adapter)
        Delete Device    ${olt_device_id}
        Delete Device in BBF    ${olt_device_id}
        # Retrive from BBF Adapter an Update XML that contain all the devices
        ALL DEVICES XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Check that the OLT and the ONUs are actually removed from the system
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device Removed
        ...    ${olt_serial_number}
        # Check if the OLT has been removed from the system
        Validate Device Removed in BBF  ${olt_serial_number}
        # Validate if all the ONUS connected at the OLT revomed are also been removed in VOLTHA
        Run Keyword and Continue On Failure    Validate all ONUS for OLT Removed    ${num_all_onus}    ${hosts}
        ...    ${olt_serial_number}    ${timeout}
        # Validate if all the ONUS connected at the OLT revomed are also been removed in BBF Adapter
        Validate all ONUS for OLT Removed in BBF   ${olt_serial_number}
        #Wait Until Keyword Succeeds    ${timeout}    5s
        #...    Verify Device Flows Removed    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
    END
    Teardown Suite

Test ONU Delete and Auto-Discovery for BBF
    [Documentation]    Validate the Autodiscory of an ONUs in case of Delete.
    ...     Delete the device and verify if them was really deleted.
    ...     Verify if all the Onus are re discovered in the correct way.
    ...     Verify the state after and before a subscription if needed.
    ...     Verify the connectivity if needed.
    [Tags]    bbfAdapterFunctionality    ONUAutoDiscoveryBBF
    [Setup]    Start Logging    ONUAutoDiscoveryBBF
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Stop Logging    ONUAutoDiscoveryBBF
    Clear All Devices Then Create New Device
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${nni_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get NNI Port in ONOS    ${of_id}
        # Subscribe the ONU if requested for the tests
        Run Keyword If    '${supress_add_subscriber}' == 'False'    Wait Until Keyword Succeeds    ${timeout}    2s
        ...     Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}
        ...     ${ONOS_SSH_PORT}    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify ONU state in voltha
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        @{onu_reasons}=  Create List     omci-flows-pushed
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    initial-mib-downloaded
        # Verify in the Voltha the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=${onu_reasons}
        # Verify in the BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Onu in BBF     ENABLED     ACTIVE
        ...    REACHABLE    ${src['onu']}   ${onu_reasons}
        # Delete ONU and Verify Ping Fails
        # Delete the device (actually with voltha in future with BBF Adapter)
        Delete Device    ${onu_device_id}
        Delete Device in BBF    ${onu_device_id}
        # Retrive from BBF Adapter an Update XML that contain all the devices
        ALL DEVICES XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        # Verify if the ONU has been removed from the system
        Validate Device Removed in BBF  ${src['onu']}
        Run Keyword If    ${has_dataplane}    Verify ping is successful except for given device
        ...    ${num_all_onus}    ${src['onu']}
        # Verify that no pending flows exist for the ONU port
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # ONU Auto-Discovery
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}    ${src['uni_id']}
        # Check ONU port is Enabled in ONOS
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify UNI Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Run Keyword If    ${has_dataplane}    Clean Up Linux    ${onu_device_id}
        # Re-Add Subscriber
        Run Keyword If    '${supress_add_subscriber}' == 'False'    Wait Until Keyword Succeeds    ${timeout}    2s
        ...     Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify that no pending flows exist for the ONU port
        Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        # Retrive from BBF Adapter an Update XML that contain the ONUs
        ONU XML update From BBF     ${CURDIR}/data.xml  ${scripts}
        @{onu_reasons}=  Create List     omci-flows-pushed
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    initial-mib-downloaded
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=${onu_reasons}
        # Verify in the BBF Adapter the State of the ONU
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Onu in BBF     ENABLED     ACTIVE
        ...    REACHABLE    ${src['onu']}   ${onu_reasons}
        # Verify Meters in ONOS
        #Wait Until Keyword Succeeds    ${timeout}    5s
        #...    Verify Meters in ONOS Ietf    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}    ${onu_port}
        Run Keyword If    ${has_dataplane}    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
    END
    # Verify flows for all OLTs
    #Wait Until Keyword Succeeds    ${timeout}    5s    Validate All OLT Flows


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #power_switch.robot needs it to support different vendor's power switch
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Run Keyword     Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Run Keyword     Setup    ${SOAK_TEST}
# [EOF] - delta:force
