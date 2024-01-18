# Copyright 2021-2024 Open Networking Foundation (ONF) and the ONF Contributors
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
Documentation     Tests ONU Software Upgrade
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
Resource          ../../libraries/onu_utilities.robot
Resource          ../../libraries/bbsim.robot
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

${suppressaddsubscriber}    True

# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:False
${logging}    True

# ONU Image to test for Upgrade needs to be passed in the following format:
${image_version}    ${EMPTY}
# Example value: BBSM_IMG_00002
${image_url}    ${EMPTY}
# Example value: http://bbsim0:50074/images/software-image.img
${image_vendor}    ${EMPTY}
# Example value: BBSM
${image_activate_on_success}    ${EMPTY}
# Example value: false
${image_commit_on_success}    ${EMPTY}
# Example value: false
${image_crc}    ${EMPTY}
# Example value: 0

# when voltha is running in k8s port forwarding is needed
# example: -v PORT_FORWARDING:False
${PORT_FORWARDING}    True

# Next values are default values for port forward, do not need to be passed, will be overwritten by values taken from image-url
# bbsim webserver port
# example: -v BBSIM_WEBSERVER_PORT:50074
${BBSIM_WEBSERVER_PORT}    50074
# bbsim instance
# example: -v BBSIM_INSTANCE:bbsim0
${BBSIM_INSTANCE}    bbsim0
# port forward handle
${portFwdHandle}     None

# Log Level of Helm chart
# example: -v helmloglevel:WARN
${helmloglevel}    DEBUG


*** Test Cases ***
Test ONU Upgrade
    [Documentation]    Validates the ONU Upgrade doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Requirement: Pass image details in following parameters in the robot command
    ...    onu_image_name, onu_image_url, onu_image_version, onu_image_crc, onu_image_local_dir
    ...    Note: The TC expects the image url and other parameters to be common for all ONUs on all BBSim
    ...    Check [VOL-3903] for more details
    [Tags]    functional   ONUUpgrade
    [Setup]    Start Logging    ONUUpgrade
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgrade
    Do ONU Upgrade All OLTs

Test ONU Upgrade All Activate and Commit Combinations
    [Documentation]    Validates the ONU Upgrade doesn't affect the system functionality by use all combinations of
    ...    flags activate_on_success and commit_on_success
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Requirement: Pass image details in following parameters in the robot command
    ...    onu_image_name, onu_image_url, onu_image_version, onu_image_crc, onu_image_local_dir
    ...    Note: The TC expects the image url and other parameters to be common for all ONUs on all BBSim
    ...    Check [VOL-4250] for more details
    [Tags]    functional   ONUUpgradeAllCombies
    [Setup]    Start Logging    ONUUpgradeAllCombies
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeAllCombies
    ${false_false}=    Create Dictionary    activate    false    commit    false
    ${true_false}=     Create Dictionary    activate    true     commit    false
    ${false_true}=     Create Dictionary    activate    false    commit    true
    ${true_true}=      Create Dictionary    activate    true     commit    true
    ${flag_list}=    Create List    ${false_false}     ${true_false}    ${false_true}    ${true_true}
    FOR    ${item}     IN      @{flag_list}
        Do ONU Upgrade All OLTs    ${item['activate']}    ${item['commit']}
        Delete All Devices and Verify
        Restart And Check BBSIM    ${NAMESPACE}
    END

Test ONU Upgrade Correct Indication of Download Wrong Url
    [Documentation]    Validates the ONU Upgrade download from wrong URL failure will be indicated correctly
    ...    and doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4257] for more details
    [Tags]    functional   ONUUpgradeDownloadWrongUrl
    [Setup]    Start Logging    ONUUpgradeDownloadWrongUrl
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeDownloadWrongUrl
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Download Failure Per OLT    ${bbsim_pod}    ${olt_serial_number}
        ...    url=http://bbsim0:50074/images/wrong-image.img$
        ...    dwl_dwlstate=DOWNLOAD_FAILED    dwl_reason=INVALID_URL    dwl_imgstate=IMAGE_UNKNOWN
        ...        dwlstate=DOWNLOAD_UNKNOWN       reason=NO_ERROR           imgstate=IMAGE_UNKNOWN
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Correct Indication of Download Failure
    [Documentation]    Validates the ONU Upgrade download failure will be indicated correctly and
    ...    doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-3935] for more details
    [Tags]    functional   ONUUpgradeDownloadFailure
    [Setup]    Start Logging    ONUUpgradeDownloadFailure
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeDownloadFailure
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Download Failure Per OLT    ${bbsim_pod}    ${olt_serial_number}
        ...    dwlstate=DOWNLOAD_FAILED       reason=CANCELLED_ON_ONU_STATE           imgstate=IMAGE_UNKNOWN
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Correct Indication of Downloading Abort
    [Documentation]    Validates the ONU Upgrade downloading abort will be indicated correctly and
    ...    doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4318] for more details
    [Tags]    functional   ONUUpgradeDownloadingAbort
    [Setup]    Start Logging    ONUUpgradeDownloadingAbort
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeDownloadingAbort
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Downloading Abort Per OLT    ${bbsim_pod}    ${olt_serial_number}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Correct Indication of Downloaded Abort
    [Documentation]    Validates the ONU Upgrade downloaded abort will be indicated correctly and
    ...    doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4320] for more details
    [Tags]    functional   ONUUpgradeDownloadedAbort
    [Setup]    Start Logging    ONUUpgradeDownloadedAbort
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeDownloadedAbort
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Downloaded Abort Per OLT    ${bbsim_pod}    ${olt_serial_number}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Correct Indication of Activating Abort
    [Documentation]    Validates the ONU Upgrade activating abort will be indicated correctly and
    ...    doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4319] for more details
    [Tags]    functional   ONUUpgradeActivatingAbort
    [Setup]    Start Logging    ONUUpgradeActivatingAbort
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeActivatingAbort
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Activating Abort Per OLT    ${bbsim_pod}    ${olt_serial_number}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Correct Indication of Active Abort
    [Documentation]    Validates the ONU Upgrade active abort will be indicated correctly and
    ...    doesn't affect the system functionality
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4320] for more details
    [Tags]    functional   ONUUpgradeActiveAbort
    [Setup]    Start Logging    ONUUpgradeActiveAbort
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeActiveAbort
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Active Abort Per OLT    ${bbsim_pod}    ${olt_serial_number}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Correct Indication of Committed Abort
    [Documentation]    Validates the ONU Upgrade committed abort will be indicated correctly and
    ...    doesn't affect the system functionality. Check BBSIM server transfer image counter after further download,
    ...    counter should be incremented.
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4320] for more details
    [Tags]    functional   ONUUpgradeCommittedAbort
    [Setup]    Start Logging    ONUUpgradeCommittedAbort
    [Teardown]    Run Keywords    Run Keyword If    ${portFwdHandle}!=None    Terminate Process    ${portFwdHandle}    kill=true
    ...           AND             Set Suite Variable   ${portFwdHandle}    None
    ...           AND             Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeCommittedAbort
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    # in case of bbsim is running in k8s port forwarding of WEBSERVER is needed
    ${BBSIM_INSTANCE}   ${BBSIM_WEBSERVER_PORT}=   Run Keyword If   '${image_url}'!='${EMPTY}'   Get BBSIM Svc and Webserver Port
    ${cmd}    Catenate
    ...       kubectl port-forward --address 0.0.0.0 -n ${NAMESPACE} svc/${BBSIM_INSTANCE}
    ...       ${BBSIM_WEBSERVER_PORT}:${BBSIM_WEBSERVER_PORT} &
    ${portFwdHandle}=    Run Keyword If    ${PORT_FORWARDING}    Start Process   ${cmd}    shell=true
    Set Suite Variable   ${portFwdHandle}
    Sleep    5s
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Committed Abort Per OLT    ${bbsim_pod}    ${olt_serial_number}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Correct Indication Multiple Image Download
    [Documentation]    Validates the ONU Upgrade multiple Image Download will be indicated correctly,
    ...    In case of (re-) download the same image without aborting the cached one in openonu-adapter should taken,
    ...    no further download from server has executed. Check BBSIM server transfer image counter after further download,
    ...    counter should NOT be incremented.
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4320] for more details
    [Tags]    functional   ONUUpgradeMultipleImageDownload
    [Setup]    Start Logging    ONUUpgradeMultipleImageDownload
    [Teardown]    Run Keywords    Run Keyword If    ${portFwdHandle}!=None    Terminate Process    ${portFwdHandle}    kill=true
    ...           AND             Set Suite Variable   ${portFwdHandle}    None
    ...           AND             Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeMultipleImageDownload
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    # in case of bbsim is running in k8s port forwarding of WEBSERVER is needed
    ${BBSIM_INSTANCE}   ${BBSIM_WEBSERVER_PORT}=   Run Keyword If   '${image_url}'!='${EMPTY}'   Get BBSIM Svc and Webserver Port
    ${cmd}    Catenate
    ...       kubectl port-forward --address 0.0.0.0 -n ${NAMESPACE} svc/${BBSIM_INSTANCE}
    ...       ${BBSIM_WEBSERVER_PORT}:${BBSIM_WEBSERVER_PORT} &
    ${portFwdHandle}=    Run Keyword If    ${PORT_FORWARDING}    Start Process   ${cmd}    shell=true
    Set Suite Variable   ${portFwdHandle}
    Sleep    5s
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Multiple Image Download Per OLT    ${bbsim_pod}    ${olt_serial_number}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Test ONU Upgrade Compare OMCI Message Version
    [Documentation]    Validates the ONU Upgrade duration depending on OMCI message version
    ...                - setup one ONU with baseline OMCI message (EXTRA_HELM_FLAGS=" --set omccVersion=163)
    ...                - perform a SW upgrade
    ...                - store SW upgrade duration
    ...                - delete all devices
    ...                - setup one ONU with extended OMCI message (EXTRA_HELM_FLAGS=" --set omccVersion=180)
    ...                - perform a SW upgrade
    ...                - store SW upgrade duration
    ...                - compare both duration
    ...                - duration of extended msg ONU should be at least less than 80% of the baseline one
    ...                  Check [VOL-4733] for more details
    [Tags]    functional    ONUUpgradeOmciBaselineVersusExtendedOnuGo
    [Setup]    Start Logging    ONUUpgradeOmciBaselineVersusExtendedOnuGo
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeOmciBaselineVersusExtendedOnuGo
    Do ONU Upgrade Compare OMCI Message Version

Test ONU Upgrade Image Download Simultaneously
    [Documentation]    Validates the ONU Upgrade Image Download to all ONUs simultaneously.
    ...    Test case should executed in multiple ONU (OLT) environment!
    ...    Performs the sanity and verifies all the ONUs are authenticated/DHCP/pingable
    ...    Check [VOL-4320] for more details
    [Tags]    functionalMultipleONUs   ONUUpgradeImageDownloadSimultaneously
    [Setup]    Start Logging    ONUUpgradeImageDownloadSimultaneously
    [Teardown]    Run Keywords    Run Keyword If    ${portFwdHandle}!=None    Terminate Process    ${portFwdHandle}    kill=true
    ...           AND             Set Suite Variable   ${portFwdHandle}    None
    ...           AND             Run Keyword If    ${logging}    Collect Logs
    ...           AND             Delete All Devices and Verify
    ...           AND             Restart And Check BBSIM    ${NAMESPACE}
    ...           AND             Stop Logging    ONUUpgradeImageDownloadSimultaneously
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    # in case of bbsim is running in k8s port forwarding of WEBSERVER is needed
    ${BBSIM_INSTANCE}   ${BBSIM_WEBSERVER_PORT}=   Run Keyword If   '${image_url}'!='${EMPTY}'   Get BBSIM Svc and Webserver Port
    ${cmd}    Catenate
    ...       kubectl port-forward --address 0.0.0.0 -n ${NAMESPACE} svc/${BBSIM_INSTANCE}
    ...       ${BBSIM_WEBSERVER_PORT}:${BBSIM_WEBSERVER_PORT} &
    ${portFwdHandle}=    Run Keyword If    ${PORT_FORWARDING}    Start Process   ${cmd}    shell=true
    Set Suite Variable   ${portFwdHandle}
    Sleep    5s
    Do ONU Upgrade Image Download Simultaneously
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

*** Keywords ***
Do ONU Upgrade All OLTs
    [Documentation]    This keyword performs the ONU Upgrade test on all OLTs
    [Arguments]    ${activate_on_success}=${image_activate_on_success}    ${commit_on_success}=${image_commit_on_success}
    # Add OLT device
    Setup
    # Performing Sanity Test to make sure subscribers are all DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Do ONU Upgrade Per OLT    ${bbsim_pod}    ${olt_serial_number}    ${activate_on_success}    ${commit_on_success}
        List ONUs    ${NAMESPACE}    ${bbsim_pod}
    END
    # Additional Verification
    Wait Until Keyword Succeeds    ${timeout}    2s    Delete All Devices and Verify
    Setup
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Do ONU Upgrade Per OLT
    [Documentation]    This keyword performs the ONU Upgrade test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}   ${activate_on_success}=${image_activate_on_success}
    ...            ${commit_on_success}=${image_commit_on_success}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    ${image_version}    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Download Image
        Download ONU Device Image    ${image_version}    ${image_url}    ${image_vendor}
        ...    ${activate_on_success}    ${commit_on_success}
        ...    ${image_crc}    ${onu_device_id}
        ${imageState}=    Run Keyword If    '${activate_on_success}'=='true' and '${commit_on_success}'=='false'
        ...    Set Variable    IMAGE_ACTIVE
        ...    ELSE IF    '${activate_on_success}'=='true' and '${commit_on_success}'=='true'
        ...    Set Variable    IMAGE_COMMITTED
        ...    ELSE    Set Variable    IMAGE_INACTIVE
        ${activated}=    Set Variable If    '${activate_on_success}'=='true'    True    False
        ${committed}=    Set Variable If    '${activate_on_success}'=='true' and '${commit_on_success}'=='true'
        ...    True    False
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    ${imageState}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    ${committed}    ${activated}    True
        # Activate Image
        ${imageState}=    Set Variable If    '${commit_on_success}'=='true'    IMAGE_COMMITTED    IMAGE_ACTIVE
        ${committed}=    Set Variable If    '${commit_on_success}'=='true'    True    False
        Run Keyword If    '${activate_on_success}'=='false'    Run Keywords
        ...    Activate ONU Device Image    ${image_version}    ${commit_on_success}    ${onu_device_id}
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    ${imageState}
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    ${committed}    True    True
        # Commit Image
        Run Keyword If    '${commit_on_success}'=='false'    Run Keywords
        ...    Commit ONU Device Image    ${image_version}    ${onu_device_id}
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_COMMITTED
        ...    AND    Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    True    True    True
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image On BBSim    ${NAMESPACE}    ${bbsim_pod}
        ...    ${src['onu']}    software_image_committed
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
        # to remove the image again from adapter, Multi-Onu tests could be restructured - not yet in focus
        Remove Adapter Image    ${image_version}    ${onu_device_id}
    END

Do ONU Upgrade Download Failure Per OLT
    [Documentation]    This keyword performs the ONU Upgrade Dowload Failure test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}    ${url}=${image_url}
    ...            ${dwl_dwlstate}=DOWNLOAD_STARTED    ${dwl_reason}=NO_ERROR    ${dwl_imgstate}=IMAGE_UNKNOWN
    ...            ${dwlstate}=DOWNLOAD_SUCCEEDED    ${reason}=NO_ERROR    ${imgstate}=IMAGE_INACTIVE
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    INVALID_IMAGE    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Download Image
        Download ONU Device Image    INVALID_IMAGE    ${url}    ${image_vendor}
        ...    ${image_activate_on_success}    ${image_commit_on_success}    ${image_crc}    ${onu_device_id}
        ...    download_state=${dwl_dwlstate}    expected_reason=${dwl_reason}    image_state=${dwl_imgstate}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    INVALID_IMAGE
        ...    ${onu_device_id}    ${dwlstate}    ${reason}    ${imgstate}
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
        # to remove the image again from adapter, Multi-Onu tests could be restructured - not yet in focus
        Remove Adapter Image    INVALID_IMAGE    ${onu_device_id}
    END

Do ONU Upgrade Downloading Abort Per OLT
    [Documentation]    This keyword performs the ONU Upgrade Downloading Abort test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}    ${url}=${image_url}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    ${image_version}    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Download Image
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    ${image_activate_on_success}    ${image_commit_on_success}    ${image_crc}    ${onu_device_id}
        Abort ONU Device Image    ${image_version}    ${onu_device_id}
        ...    DOWNLOAD_STARTED    CANCELLED_ON_REQUEST    IMAGE_DOWNLOADING
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_CANCELLED    CANCELLED_ON_REQUEST    IMAGE_UNKNOWN
        #   !!!    Expected is image is not visible in list   !!!
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    False    False    False    image_should_not_in_list=True
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
    END

Do ONU Upgrade Downloaded Abort Per OLT
    [Documentation]    This keyword performs the ONU Upgrade Downloaded Abort test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}    ${url}=${image_url}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    ${image_version}    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Download Image
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    false    false    ${image_crc}    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_INACTIVE
        Abort ONU Device Image    ${image_version}    ${onu_device_id}
        ...    DOWNLOAD_SUCCEEDED    CANCELLED_ON_REQUEST    IMAGE_INACTIVE
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    CANCELLED_ON_REQUEST    IMAGE_INACTIVE
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    False    False    True
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
    END

Do ONU Upgrade Activating Abort Per OLT
    [Documentation]    This keyword performs the ONU Upgrade Activating Abort test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}    ${url}=${image_url}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    ${image_version}    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Download Image
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    false    false    ${image_crc}    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_INACTIVE
        Activate ONU Device Image    ${image_version}    false    ${onu_device_id}
        Abort ONU Device Image    ${image_version}    ${onu_device_id}
        ...    DOWNLOAD_SUCCEEDED    CANCELLED_ON_REQUEST    IMAGE_ACTIVATING
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    CANCELLED_ON_REQUEST    IMAGE_ACTIVATION_ABORTED
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    False    True    True
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
    END

Do ONU Upgrade Active Abort Per OLT
    [Documentation]    This keyword performs the ONU Upgrade Active Abort test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}    ${url}=${image_url}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    ${image_version}    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # Download Image
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    false    false    ${image_crc}    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_INACTIVE
        Activate ONU Device Image    ${image_version}    false    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_ACTIVE
        Abort ONU Device Image    ${image_version}    ${onu_device_id}
        ...    DOWNLOAD_SUCCEEDED    CANCELLED_ON_REQUEST    IMAGE_ACTIVE
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    CANCELLED_ON_REQUEST    IMAGE_ACTIVE
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    False    True    True
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
    END

Do ONU Upgrade Committed Abort Per OLT
    [Documentation]    This keyword performs the ONU Upgrade Committed Abort test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}    ${url}=${image_url}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    ${image_version}    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${Images_Count_Start}=    Get Images Count
        # Download Image
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    false    false    ${image_crc}    ${onu_device_id}
        # After download of image, check image counter of BBSIM, has to be incremented by 2, because bbsim increments counter
        # whenever openonu adapter touch the image, so one increment for check image is available and one for downloading
        ${Images_Count_First}=    Get Images Count
        ${Images_Count_Start}=    Evaluate    ${Images_Count_Start}+2
        Should Be Equal as Integers    ${Images_Count_First}    ${Images_Count_Start}    Count of image download not correct!
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_INACTIVE
        Activate ONU Device Image    ${image_version}    false    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_ACTIVE
        Commit ONU Device Image    ${image_version}    ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_COMMITTED
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    True    True    True
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image On BBSim    ${NAMESPACE}    ${bbsim_pod}
        ...    ${src['onu']}    software_image_committed
        Abort ONU Device Image    ${image_version}    ${onu_device_id}
        ...    DOWNLOAD_UNKNOWN    NO_ERROR    IMAGE_UNKNOWN
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_UNKNOWN    NO_ERROR    IMAGE_UNKNOWN
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    True    True    True
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
        ${Images_Count_Intermediate}=    Get Images Count
        # Repeat download of aborted image, check image counter of BBSIM, has to be incremented by 2, because bbsim increments
        # whenever openonu adapter touch the image, so one increment for check image is available and one for downloading
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    false    false    ${image_crc}    ${onu_device_id}
        ${Images_Count_End}=    Get Images Count
        ${Images_Count_Intermediate}=    Evaluate    ${Images_Count_Intermediate}+2
        Should Be Equal as Integers    ${Images_Count_End}    ${Images_Count_Intermediate}   Count of image download not correct!
        Remove Adapter Image    ${image_version}    ${onu_device_id}
    END

Do ONU Upgrade Multiple Image Download Per OLT
    [Documentation]    This keyword performs the ONU Upgrade Image Download test on single OLT
    [Arguments]    ${bbsim_pod}    ${olt_serial_number}    ${url}=${image_url}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL'    Remove Adapter Image    ${image_version}    ${onu_device_id}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${Images_Count_Start}=    Get Images Count
        # Download Image
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    true    true    ${image_crc}    ${onu_device_id}
        # After download of image, check image counter of BBSIM, has to be incremented by 2, because bbsim increments counter
        # whenever openonu adapter touch the image, so one increment for check image is available and one for downloading
        ${Images_Count_First}=    Get Images Count
        ${Images_Count_Start}=    Evaluate    ${Images_Count_Start}+2
        Should Be Equal as Integers    ${Images_Count_First}    ${Images_Count_Start}    Count of image download not correct!
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_COMMITTED
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    True    True    True
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image On BBSim    ${NAMESPACE}    ${bbsim_pod}
        ...    ${src['onu']}    software_image_committed
        Wait Until Keyword Succeeds    ${timeout}    5s    Perform Sanity Test     ${suppressaddsubscriber}
        ${Images_Count_Intermediate}=    Get Images Count
        # Repeat download of same image, check image counter of BBSIM, has to be not incremented, because no download from
        # server will be executed, the cached one from openonu-adapter will taken
        Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
        ...    false    false    ${image_crc}    ${onu_device_id}
        ${Images_Count_End}=    Get Images Count
        Should Be Equal as Integers    ${Images_Count_End}    ${Images_Count_Intermediate}   Count of image download not correct!
        Remove Adapter Image    ${image_version}    ${onu_device_id}
    END

Do ONU Upgrade Compare OMCI Message Version
    [Documentation]    This keyword performs the ONU Upgrade Compare OMCI Message Version test for the first OLT/ONU
    [Arguments]    ${activate_on_success}=${image_activate_on_success}    ${commit_on_success}=${image_commit_on_success}
    [Teardown]     Run Keyword If  '${KEYWORD STATUS}'=='FAIL' and '${onu_device_id}'!='${EMPTY}'
    ...            Remove Adapter Image    ${image_version}    ${onu_device_id}
    ${onu_device_id}=  Set Variable    ${EMPTY}
    ${firstonu}=       Set Variable    0
    ${outputfile}=     Set variable    ${OUTPUTDIR}/ONU_SW_Upgrade_Time.txt
    ${omcc_version}    ${is_omcc_extended}=    Get BBSIM OMCC Version    ${NAMESPACE}
    # Restart BBSIM with OMCI Baseline Message if needed
    Create File    ${outputfile}    This file contains the SW Upgrade download durations
    ${extra_helm_flags}    Catenate    --set omccVersion=163
    Run Keyword If    ${is_omcc_extended}    Restart BBSIM by Helm Charts    ${NAMESPACE}    extra_helm_flags=${extra_helm_flags}
    # Add OLT device
    Setup
    ${src}=    Set Variable    ${hosts.src[${firstonu}]}
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    omci-flows-pushed
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${src['onu']}    onu=True    onu_reason=${onu_state}
    ${baselineonu}=    Get ONU SW Upgrade Duration    ${firstonu}   ${activate_on_success}    ${commit_on_success}
    Log    ONU ${src['onu']}: downloaded SW upgrade in ${baselineonu} sec for OMCI baseline message.    console=yes
    Append To File    ${outputfile}
    ...    \r\nONU ${src['onu']} downloaded SW upgrade in ${baselineonu} sec for OMCI baseline message.
    # get ONU OMCI counter statistics
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${rc}    ${OMCI_counter_dict}=    Get OMCI counter statistics dictionary   ${onu_device_id}
    Run Keyword If    ${rc} != 0    FAIL    Could not get baseline ONU OMCI counter statistic of ONU ${src['onu']}!
    ${BaseTxNoArFrames}=    Get From Dictionary   ${OMCI_counter_dict}   BaseTxNoArFrames
    Should Be True   0 < ${BaseTxNoArFrames}    No BaseTxNoArFrames found in baseline OMCI!
    # some additional checks
    ${ExtRxAkFrames}=           Get From Dictionary   ${OMCI_counter_dict}   ExtRxAkFrames
    ${ExtRxNoAkFrames}=         Get From Dictionary   ${OMCI_counter_dict}   ExtRxNoAkFrames
    ${ExtTxArFrames}=           Get From Dictionary   ${OMCI_counter_dict}   ExtTxArFrames
    ${ExtTxNoArFrames}=         Get From Dictionary   ${OMCI_counter_dict}   ExtTxNoArFrames
    ${TxOmciCounterRetries}=    Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterRetries
    ${TxOmciCounterTimeouts}=   Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterTimeouts
    Should Be Equal   0   ${ExtRxAkFrames}          ExtRxAkFrames found in baseline OMCI!
    Should Be Equal   0   ${ExtRxNoAkFrames}        ExtRxNoAkFrames found in baseline OMCI!
    Should Be Equal   0   ${ExtTxArFrames}          ExtTxArFrames found in baseline OMCI!
    Should Be Equal   0   ${ExtTxNoArFrames}        ExtTxNoArFrames found in baseline OMCI!
    Should Be Equal   0   ${TxOmciCounterRetries}   TxOmciCounterRetries found in baseline OMCI!
    Should Be Equal   0   ${TxOmciCounterTimeouts}  TxOmciCounterTimeouts found in baseline OMCI!
    Delete All Devices and Verify
    # Restart BBSIM with OMCI Extended Message
    ${extra_helm_flags}=    Run Keyword If    ${is_omcc_extended}     Catenate    --set omccVersion=${omcc_version}
    ...     ELSE     Catenate    --set omccVersion=180
    Restart BBSIM by Helm Charts    ${NAMESPACE}    extra_helm_flags=${extra_helm_flags}
    # Start Onu again with OMCI Extended Message
    Setup
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    1s
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${src['onu']}    onu=True    onu_reason=${onu_state}
    ${extendedonu}=    Get ONU SW Upgrade Duration    ${firstonu}   ${activate_on_success}    ${commit_on_success}
    Log    ONU ${src['onu']}: downloaded SW upgrade in ${extendedonu} sec for OMCI extended message.    console=yes
    Append To File    ${outputfile}
    ...    \r\nONU ${src['onu']} downloaded SW upgrade in ${extendedonu} sec for OMCI extended message.
    ${duration_compare}=    Evaluate    ${baselineonu}*0.8 > ${extendedonu}
    Should Be True    ${duration_compare}   SW Upgrade too slow for OMCI extended message!
    # get ONU OMCI counter statistics
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${rc}    ${OMCI_counter_dict}=    Get OMCI counter statistics dictionary   ${onu_device_id}
    Run Keyword If    ${rc} != 0    FAIL    Could not get extended ONU OMCI counter statistic of ONU ${src['onu']}!
    ${ExtTxNoArFrames}=    Get From Dictionary    ${OMCI_counter_dict}    ExtTxNoArFrames
    Should Be True   0 < ${ExtTxNoArFrames}    No ExtTxNoArFrames found in extended OMCI!
    # check baseline and extended OMCI frames counter
    ${TxNoArFrames_compare}=   Evaluate   ${BaseTxNoArFrames}*0.05 > ${ExtTxNoArFrames}
    Should Be True    ${TxNoArFrames_compare}   Comparison of TxNoArFrames failed (${BaseTxNoArFrames}:${ExtTxNoArFrames})!
    # some additional checks
    ${TxOmciCounterRetries}=    Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterRetries
    ${TxOmciCounterTimeouts}=   Get From Dictionary   ${OMCI_counter_dict}   TxOmciCounterTimeouts
    Should Be Equal   0   ${TxOmciCounterRetries}   TxOmciCounterRetries found in extended OMCI!
    Should Be Equal   0   ${TxOmciCounterTimeouts}  TxOmciCounterTimeouts found in extended OMCI!
    # Restart BBSIM with OMCI Message Version read at begin of test
    ${extra_helm_flags}=    Catenate    --set omccVersion=${omcc_version}
    Run Keyword Unless   ${is_omcc_extended}   Restart BBSIM by Helm Charts   ${NAMESPACE}   extra_helm_flags=${extra_helm_flags}

Get ONU SW Upgrade Duration
    [Documentation]    This keyword delivers SW Upgrade duration of onu
    [Arguments]    ${onu}   ${activate_on_success}    ${commit_on_success}
    ${src}=    Set Variable    ${hosts.src[${onu}]}
    ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
    ${timeStart}=    Get Current Date
    Download ONU Device Image    ${image_version}    ${image_url}    ${image_vendor}
    ...    ${activate_on_success}    ${commit_on_success}
    ...    ${image_crc}    ${onu_device_id}
    ${imageState}=    Run Keyword If    '${activate_on_success}'=='true' and '${commit_on_success}'=='false'
    ...    Set Variable    IMAGE_ACTIVE
    ...    ELSE IF    '${activate_on_success}'=='true' and '${commit_on_success}'=='true'
    ...    Set Variable    IMAGE_COMMITTED
    ...    ELSE    Set Variable    IMAGE_INACTIVE
    ${activated}=    Set Variable If    '${activate_on_success}'=='true'    True    False
    ${committed}=    Set Variable If    '${activate_on_success}'=='true' and '${commit_on_success}'=='true'
    ...    True    False
    Wait Until Keyword Succeeds    ${timeout}    0s    Verify ONU Device Image Status    ${image_version}
    ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    ${imageState}
    ${timeCurrent} =    Get Current Date
    ${timeTotalMs} =    Subtract Date From Date    ${timeCurrent}    ${timeStart}    result_format=number
    Remove Adapter Image    ${image_version}    ${onu_device_id}
    [Return]    ${timeTotalMs}

Do ONU Upgrade Image Download Simultaneously
    [Documentation]    This keyword performs the ONU Upgrade Image Download Simultaneously on all ONUs test
    [Arguments]    ${url}=${image_url}
    [Teardown]     Remove Adapter Image from ONUs    ${image_version}    ${list_onus}
    # collect all ONU's device ids
    ${list_onus}    Create List
    Build ONU Device Id List    ${list_onus}
    # prepare OLT-SN BBSIM-POD releation dictionary for later fast access
    ${olt_bbsim_dict}=     Create Dictionary
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${bbsim_rel}=    Catenate    SEPARATOR=    bbsim    ${J}
        ${bbsim_pod}=    Get Pod Name By Label    ${NAMESPACE}    release     ${bbsim_rel}
        Set To Dictionary    ${olt_bbsim_dict}    ${olt_serial_number}    ${bbsim_pod}
    END
    ${Images_Count_Start}=    Get Images Count
    # Download Image to all ONUs simultaneously
    ${onu_device_ids} =    Catenate    @{list_onus}
    Download ONU Device Image    ${image_version}    ${url}    ${image_vendor}
    ...    true    true    ${image_crc}    ${onu_device_ids}
    # do all the check stuff
    FOR  ${onu_device_id}  IN  @{list_onus}
        Log  ${onu_device_id}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image Status    ${image_version}
        ...    ${onu_device_id}    DOWNLOAD_SUCCEEDED    NO_ERROR    IMAGE_COMMITTED
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image List    ${onu_device_id}
        ...    ${image_version}    True    True    True
    END
    # last but not least check bbsim
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${bbsim_pod}=    Get From Dictionary    ${olt_bbsim_dict}    ${src['olt']}
        Wait Until Keyword Succeeds    ${timeout}    2s    Verify ONU Device Image On BBSim    ${NAMESPACE}    ${bbsim_pod}
        ...    ${src['onu']}    software_image_committed
    END
    ${Images_Count_End}=    Get Images Count
    ${Images_Count_Start}=    Evaluate    ${Images_Count_Start}+2
    Should Be Equal as Integers    ${Images_Count_End}    ${Images_Count_Start}   Count of image download not correct!

Setup Suite
    [Documentation]    Set up the test suite
    Start Logging Setup or Teardown    Setup-${SUITE NAME}
    Common Test Suite Setup
    # set log level for org.onosproject.store.device.impl.GossipDeviceStore to TRACE to get reason for hanging ONOS resources
    ${LogLevelGossipDeviceStore}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    log:get org.onosproject.store.device.impl.GossipDeviceStore
    Set Suite Variable    ${LogLevelGossipDeviceStore}
    Log    Old Log Level of GossipDeviceStore is ${LogLevelGossipDeviceStore}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    log:set TRACE org.onosproject.store.device.impl.GossipDeviceStore
     ${NewLogLevelGossipDeviceStore}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    log:get org.onosproject.store.device.impl.GossipDeviceStore
    Log    New Log Level of GossipDeviceStore is ${NewLogLevelGossipDeviceStore}
    Run Keyword If    ${logging}    Collect Logs
    Stop Logging Setup or Teardown    Setup-${SUITE NAME}

Teardown Suite
    [Documentation]    Tear down steps for the suite
    Start Logging Setup or Teardown    Teardown-${SUITE NAME}
    # stop port forwarding if still running
    Run Keyword If    ${portFwdHandle}!=None    Terminate Process    ${portFwdHandle}    kill=true
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Run Keyword If    ${logging}    Collect Logs
    # reset log level for org.onosproject.store.device.impl.GossipDeviceStore to to previous level
     ${NewLogLevelGossipDeviceStore}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    log:get org.onosproject.store.device.impl.GossipDeviceStore
    Log    Log Level of GossipDeviceStore is ${NewLogLevelGossipDeviceStore}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    log:set ${LogLevelGossipDeviceStore} org.onosproject.store.device.impl.GossipDeviceStore
     ${LogLevelGossipDeviceStore}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Execute ONOS CLI Command use single connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    log:get org.onosproject.store.device.impl.GossipDeviceStore
    Log    New Log Level of GossipDeviceStore is ${LogLevelGossipDeviceStore}
    Stop Logging Setup or Teardown    Teardown-${SUITE NAME}
    Close All ONOS SSH Connections
