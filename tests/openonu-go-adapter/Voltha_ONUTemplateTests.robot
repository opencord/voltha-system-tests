*** Settings ***
Documentation     Test Template handling of ONU Go adapter with BBSIM controlledActivation: only-onu only!
...               Values.yaml must contain 'onu: 2' and 'controlledActivation: only-onu' under BBSIM!
...               Run robot with bbsim-kind-2x2.yaml
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
${NAMESPACE}      voltha
${timeout}        180s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    True
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

# flag debugmode is used, if true timeout calculation various, can be passed via the command line too
# example: -v debugmode:True
${debugmode}    False
# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
# if True execution will be paused before clean up
# example: -v pausebeforecleanup:True
${pausebeforecleanup}    False
${data_dir}    ../data


*** Test Cases ***
ONU MIB Template Data Test
    [Documentation]    Validates ONU Go adapter storage of MIB Template Data in etcd and checks the usage
    ...                - setup one ONU
    ...                - request MIB-Upload-Data by ONU via OMCI
    ...                - storage MIB-Upload-Data in etcd
    ...                - store setup duration of ONU
    ...                - check Template-Data in etcd stored (service/voltha/omci_mibs/go_templates/)
    ...                - setup second ONU
    ...                - collect setup durationof second ONU
    ...                - compare both duration
    ...                - duration of second ONU should be at least 10 times faster than the first one
    ...                - MIB-Upload-Data should not requested via OMCI by second ONU
    ...                - MIB-Upload-Data should read from etcd
    [Tags]    functionalOnuGo    MibTemplateOnuGo
    [Setup]    Run Keywords    Start Logging    ONUMibTemplateTest
    ...    AND    Setup
    Perform ONU MIB Template Data Test
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUMibTemplateTest


*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable  ${onos_ssh_connection}
    # delete etcd MIB Template Data
    Delete MIB Template Data

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    ...    Furthermore gives the possibility to pause the execution.
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    Wait for Ports in ONOS      ${onos_ssh_connection}  0   BBSM
    # delete etcd MIB Template Data (for repeating test)
    Delete MIB Template Data
    Close ONOS SSH Connection   ${onos_ssh_connection}

Perform ONU MIB Template Data Test
    [Documentation]    This keyword performs ONU MIB Template Data Test
    ${firstonu}=    Set Variable    0
    ${secondonu}=    Set Variable    1
    ${state2test}=    Set Variable    6
    Set Global Variable    ${state2test}
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    # Start first Onu
    Log    \r\nONU BBSM00000001: startup with MIB upload cycle and storage of template data to etcd.    console=yes
    ${result}=    Exec Pod    ${NAMESPACE}    bbsim    bbsimctl onu poweron BBSM00000001
    Should Contain    ${result}    successfully    msg=Can not poweron BBSM00000001    values=False
    ${timeStart}=    Get Current Date
    ${firstonustartup}=    Get ONU Startup Duration    ${firstonu}    ${timeStart}
    # check MIB Template data stored in etcd
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Verify MIB Template Data Available
    # Start second Onu
    Log    ONU BBSM00000002: startup without MIB upload cycle by using of template data of etcd.    console=yes
    ${result}=    Exec Pod    ${NAMESPACE}    bbsim    bbsimctl onu poweron BBSM00000002
    Should Contain    ${result}    successfully    msg=Can not poweron BBSM00000002    values=False
    ${timeStart}=    Get Current Date
    ${secondonustartup}=    Get ONU Startup Duration    ${secondonu}    ${timeStart}
    # compare both durations, second onu should be at least 3 times faster
    ${status}    Evaluate    ${firstonustartup}>=${secondonustartup}*3
    Should Be True    ${status}
    ...    Startup durations (${firstonustartup} and ${secondonustartup}) do not full fill the requirements of 1/10.

Get ONU Startup Duration
    [Documentation]    This keyword delivers startup duration of onu
    [Arguments]    ${onu}    ${starttime}
    ${src}=    Set Variable    ${hosts.src[${onu}]}
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state}=    Map State    ${state2test}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
    ...    ${src['onu']}    onu=True    onu_reason=${onu_state}
    ${timeCurrent} =    Get Current Date
    ${timeTotalMs} =    Subtract Date From Date    ${timeCurrent}    ${startTime}    result_format=number
    Log    ONU ${src['onu']}: reached the state ${onu_state} after ${timeTotalMs} sec.    console=yes
    [Return]    ${timeTotalMs}

Verify MIB Template Data Available
    [Documentation]    This keyword verifies MIB Template Data stored in etcd
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commandget}
    Should Not Be Empty    ${result}    No MIB Template Data stored in etcd!

Delete MIB Template Data
    [Documentation]    This keyword deletes MIB Template Data stored in etcd
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
    ${commanddel}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commanddel}
    Sleep    3s
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/omci_mibs/go_templates/'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commandget}
    Should Be Empty    ${result}    Could not delete MIB Template Data stored in etcd!

Map State
    [Documentation]    This keyword converts the passed numeric value or name of a onu state to its state values.
    [Arguments]    ${state}
    # create state lists with corresponding return values
    #                             ADMIN-STATE OPER-STATUS   CONNECT-STATUS ONU-STATE
    ${state1}    Create List      ENABLED     ACTIVATING    REACHABLE      activating-onu
    ${state2}    Create List      ENABLED     ACTIVATING    REACHABLE      starting-openomci
    ${state3}    Create List      ENABLED     ACTIVATING    REACHABLE      discovery-mibsync-complete
    ${state4}    Create List      ENABLED     ACTIVE        REACHABLE      initial-mib-downloaded
    ${state5}    Create List      ENABLED     ACTIVE        REACHABLE      tech-profile-config-download-success
    ${state6}    Create List      ENABLED     ACTIVE        REACHABLE      omci-flows-pushed
    ${state7}    Create List      DISABLED    UNKNOWN       REACHABLE      omci-admin-lock
    ${state8}    Create List      ENABLED     ACTIVE        REACHABLE      onu-reenabled
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state}=    Set Variable If
    ...    '${state}'=='1' or '${state}'=='activating-onu'                          ${state1}
    ...    '${state}'=='2' or '${state}'=='starting-openomci'                       ${state2}
    ...    '${state}'=='3' or '${state}'=='discovery-mibsync-complete'              ${state3}
    ...    '${state}'=='4' or '${state}'=='initial-mib-downloaded'                  ${state4}
    ...    '${state}'=='5' or '${state}'=='tech-profile-config-download-success'    ${state5}
    ...    '${state}'=='6' or '${state}'=='omci-flows-pushed'                       ${state6}
    ...    '${state}'=='7' or '${state}'=='omci-admin-lock'                         ${state7}
    ...    '${state}'=='8' or '${state}'=='onu-reenabled'                           ${state8}
    [Return]    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state}
