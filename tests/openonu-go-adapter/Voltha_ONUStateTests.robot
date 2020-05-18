*** Settings ***
Documentation     Test states of ONU Go adapter
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite
Test Setup        Setup
Test Teardown     Teardown
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
${timeout}        120s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    True
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}
# state to test variable, can be passed via the command line too
${state2test}    6
${testmode}    SingleState
${porttest}    True

*** Test Cases ***
ONU State Test
    [Documentation]    Validates the ONU Go adapter states
    [Tags]    statetest
    [Setup]    Run Keywords    Start Logging    ONUStateTest
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Enable Device    ${olt_device_id}
    ${timeStart} =    Get Current Date
    Set Global Variable    ${timeStart}
    Run Keyword If    "${testmode}"=="SingleState"    Do ONU Single State Test
    ...    ELSE IF    "${testmode}"=="Up2State"    Do ONU Up To State Test
    ...    ELSE IF    "${testmode}"=="SingleStateTime"    Do ONU Single State Test Time
    ...    ELSE    Fail    The testmode (${testmode}) is not valid!
    Run Keyword If    ${porttest}    Do Onu Port Check
    [Teardown]    Run Keywords    Collect Logs
    ...    AND    Stop Logging    ONUStateTest

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    Run Keyword If   ${num_onus}>4    Calculate Timeout

Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ip}    ${olt_user}    ${olt_pass}
    Run Keyword If    ${has_dataplane}    Sleep    60s
    #create/preprovision device
    ${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    Set Suite Variable    ${olt_device_id}
    #validate olt states
    Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    ...    ${olt_device_id}
    Sleep    5s

Calculate Timeout
    [Documentation]    Calculates the timeout regarding num-onus in case of more than 4 onus
    ${timeout}    Fetch From Left    ${timeout}    s
    ${timeout}=    evaluate    ${timeout}+((${num_onus}-4)*30)
    ${timeout}=    Catenate    SEPARATOR=    ${timeout}    s
    Set Suite Variable    ${timeout}
    #Log    \r\nTimeout: ${timeout}    INFO    console=True

Do ONU Up To State Test
    [Documentation]    This keyword performs Up2State Test
    ...    All states up to the passed have to be checked
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If   ${state2test}>=1
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=activating-onu
        Run Keyword If   ${state2test}>=2
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=starting-openomci
        Run Keyword If   ${state2test}>=3
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=discovery-mibsync-complete
        Run Keyword If   ${state2test}>=4
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=initial-mib-downloaded
        Run Keyword If   ${state2test}>=5
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=tech-profile-config-download-success
        Run Keyword If   ${state2test}>=6
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
    END

Do ONU Single State Test
    [Documentation]    This keyword performs SingleState Test
    ...    Only the passed state has to be checked
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If    ${state2test}==1
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=activating-onu
        ...    ELSE IF    ${state2test}==2
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=starting-openomci
        ...    ELSE IF    ${state2test}==3
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=discovery-mibsync-complete
        ...    ELSE IF    ${state2test}==4
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=initial-mib-downloaded
        ...    ELSE IF    ${state2test}==5
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=tech-profile-config-download-success
        ...    ELSE IF    ${state2test}==6
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        ...    ELSE    Fail    The state to test (${state2test}) is not valid!
    END

Do ONU Single State Test Time
    [Documentation]    This keyword performs SingleState Test with calculate running time
    ...    Only the passed state has to be checked and the duration each single onu adapter needed
    ...    will be calculated and printed out
    ${ListfinishedONUs}    Create List
    Set Global Variable    ${ListfinishedONUs}
	Create File    ONU_Startup_Time.txt    This file contains the startup times of all ONUs.
    ${list_onus}    Create List
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu}    Evaluate    ${hosts.src}[${I}].get("onu")
        Append To List    ${list_onus}    ${onu}
    END
    Run Keyword If    ${state2test}==1
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration   ENABLED    ACTIVATING    REACHABLE
    ...    ${list_onus}    onu_reason=activating-onu
    ...    ELSE IF    ${state2test}==2
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration    ENABLED    ACTIVATING    REACHABLE
    ...    ${list_onus}    onu_reason=starting-openomci
    ...    ELSE IF    ${state2test}==3
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration    ENABLED    ACTIVATING    REACHABLE
    ...    ${list_onus}    onu_reason=discovery-mibsync-complete
    ...    ELSE IF    ${state2test}==4
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration    ENABLED    ACTIVE    REACHABLE
    ...    ${list_onus}    onu_reason=initial-mib-downloaded
    ...    ELSE IF    ${state2test}==5
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration    ENABLED    ACTIVE    REACHABLE
    ...    ${list_onus}    onu_reason=tech-profile-config-download-success
    ...    ELSE IF    ${state2test}==6
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices With Duration    ENABLED    ACTIVE    REACHABLE
    ...    ${list_onus}    onu_reason=omci-flows-pushed
    ...    ELSE    Fail    The state to test (${state2test}) is not valid!

Do Onu Port Check
    [Documentation]    This keyword performs Onu Port Check
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
    END

Validate ONU Devices With Duration
    [Documentation]
    ...    Parses the output of "voltctl device list" and inspects all devices ${List_ONU_Serial},
    ...    Iteratively match on each Serial number contained in ${List_ONU_Serial} and inspect
    ...    states including MIB state.
    [Arguments]    ${admin_state}    ${oper_status}    ${connect_status}    ${List_ONU_Serial}
    ...    ${onu_reason}=${EMPTY}    
    ${rc}    ${output}=    Run and Return Rc and Output    ${VOLTCTL_CONFIG}; voltctl device list -o json
    Should Be Equal As Integers    ${rc}    0
    ${timeCurrent} =    Get Current Date
    ${jsondata}=    To Json    ${output}
    ${length}=    Get Length    ${jsondata}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${matched}=    Set Variable    False
        ${value}=    Get From List    ${jsondata}    ${INDEX}
        ${astate}=    Get From Dictionary    ${value}    adminstate
        ${opstatus}=    Get From Dictionary    ${value}    operstatus
        ${cstatus}=    Get From Dictionary    ${value}    connectstatus
        ${sn}=    Get From Dictionary    ${value}    serialnumber
        ${mib_state}=    Get From Dictionary    ${value}    reason
        ${finished_id}=    Get Index From List    ${ListfinishedONUs}   ${sn} 
        ${onu_id}=    Get Index From List    ${List_ONU_Serial}   ${sn} 
        ${matched}=    Set Variable If    -1 == ${finished_id}    True    False
        ${matched}=    Set Variable If    -1 != ${onu_id}    ${matched}    False
        ${matched}=    Set Variable If    '${astate}' == '${admin_state}'    ${matched}    False
        ${matched}=    Set Variable If    '${opstatus}' == '${oper_status}'    ${matched}    False
        ${matched}=    Set Variable If    '${cstatus}' == '${connect_status}'    ${matched}    False
        ${matched}=    Set Variable If    '${mib_state}' == '${onu_reason}'    ${matched}    False
        Run Keyword If    ${matched}    Log And Store Finished ONU    ${sn}    ${timeCurrent}    ${onu_reason}
        Run Keyword If    ${matched}    Remove Values From List    ${List_ONU_Serial}    ${sn}
    END
	Should Be Empty    ${List_ONU_Serial}    List ${List_ONU_Serial} not empty

Log And Store Finished ONU
    [Documentation]
    ...    Log and stores the finished ONU
    [Arguments]    ${onu_sn}    ${finish_time}    ${onu_reason}
    ${timeTotalMs} =    Subtract Date From Date    ${finish_time}    ${timeStart}    result_format=number
    Log    \r\nONU ${onu_sn} reached the state ${onu_reason} after ${timeTotalMs} sec.    INFO    console=True
    Append To File    ONU_Startup_Time.txt    \r\nONU ${onu_sn} reached the state ${onu_reason} after ${timeTotalMs} sec.
    Append To List    ${ListfinishedONUs}    ${onu_sn}
    Set Global Variable    ${ListfinishedONUs}
