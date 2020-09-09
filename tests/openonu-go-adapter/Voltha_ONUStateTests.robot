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
${timeout}        180s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    True
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}
# state to test variable, can be passed via the command line too, valid values: 1-6
# 1 -> activating-onu
# 2 -> starting-openomci
# 3 -> discovery-mibsync-complete
# 4 -> initial-mib-downloaded
# 5 -> tech-profile-config-download-success
# 6 -> omci-flows-pushed
# example: -v state2test:5
${state2test}    6
# test mode variable, can be passed via the command line too, valid values: SingleState, Up2State, SingleStateTime
# example: -v testmode:SingleStateTime
${testmode}    SingleState
# flag for execute Tech Profile check, can be passed via the command line too
# example: -v profiletest:False
${profiletest}    True
# used tech profile, can be passed via the command line too, valid values: default (=1T1GEM), 1T4GEM, 1T8GEM
# example: -v techprofile:1T4GEM
${techprofile}    default
# flag for execute port test, can be passed via the command line too
# example: -v porttest:False
${porttest}    True
# flag for execute flow test, can be passed via the command line too
# example: -v flowtest:False
${flowtest}    True
# flag for execute reconcile onu device test, can be passed via the command line too
# example: -v reconciletest:True
${reconciletest}    False
# flag for execute onu device state test after reconcile, can be passed via the command line too
# example: -v reconcilestatetest:True
${reconcilestatetest}    False
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
ONU State Test
    [Documentation]    Validates the ONU Go adapter states
    [Tags]    statetest    onutest
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
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUStateTest

Check Loaded Tech Profile
    [Documentation]    Validates the loaded Tech Profile
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    ...    Check will be executed only the reached ONU state is 5 (tech-profile-config-download-success) or higher
    [Tags]    onutest
    [Setup]    Start Logging    ONUCheckTechProfile
    Run Keyword If    ${state2test}>=5 and ${profiletest}    Do Check Tech Profile
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUCheckTechProfile

Onu Port Check
    [Documentation]    Validates that all the UNI ports show up in ONOS
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    onutest
    [Setup]    Start Logging    ONUPortTest
    Run Keyword If    ${porttest}    Do Onu Port Check
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUPortTest

Reconcile Onu Device
    [Documentation]    Reconciles ONU Device and check state
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    onutest
    [Setup]    Start Logging    ReconcileONUDevice
    Run Keyword If    ${state2test}>=5 and ${reconciletest}    Do Reconcile Onu Device
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ReconcileONUDevice

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    state2test:${state2test}, testmode:${testmode}, profiletest:${profiletest}, techprofile:${techprofile},
    ...    porttest:${porttest}, flowtest:${flowtest}, reconciletest:${reconciletest},
    ...    reconcilestatetest:${reconcilestatetest}, debugmode:${debugmode}, logging:${logging},
    ...    pausebeforecleanup:${pausebeforecleanup}
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    Run Keyword If   ${num_onus}>4    Calculate Timeout
	Run Keyword If    "${techprofile}"=="1T1GEM"    ${techprofile}=    Set Variable    default
    Run Keyword If    "${techprofile}"=="default"   Log To Console    \nTechProfile:default (1T1GEM)
    ...    ELSE IF    "${techprofile}"=="1T4GEM"    Set Tech Profile    1T4GEM
    ...    ELSE IF    "${techprofile}"=="1T8GEM"    Set Tech Profile    1T8GEM
    ...    ELSE    Fail    The TechProfile (${techprofile}) is not valid!
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable  ${onos_ssh_connection}

Teardown Suite
    [Documentation]    Replaces the Suite Teardown in utils.robot.
    ...    Cleans up and checks all ONU ports disabled in ONOS.
    ...    Furthermore gives the possibility to pause the execution.
    Run Keyword If    ${pausebeforecleanup}    Import Library    Dialogs
    Run Keyword If    ${pausebeforecleanup}    Pause Execution    Press OK to continue with clean up!
    Run Keyword If    ${pausebeforecleanup}    Log    Teardown will be continued...    console=yes
    Run Keyword If    ${teardown_device}    Delete All Devices and Verify
    # Wait for Ports in ONOS      ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}  0   BBSM
    Wait for Ports in ONOS      ${onos_ssh_connection}  0   BBSM
    Close ONOS SSH Connection   ${onos_ssh_connection}
	Remove Tech Profile

Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Run Keyword If    ${has_dataplane}    Wait Until Keyword Succeeds    120s    10s    Openolt is Up
    ...    ${olt_ssh_ip}    ${olt_user}    ${olt_pass}
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
    ${timeout}=    Set Variable If    (not ${debugmode}) and (${timeout}>600)    600    ${timeout}
    ${timeout}=    Catenate    SEPARATOR=    ${timeout}    s
    Set Suite Variable    ${timeout}

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
    Build ONU SN List    ${list_onus}
    Run Keyword If    ${state2test}==1
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    activating-onu    ${list_onus}    ${timeStart}    print2console=True
    ...    output_file=ONU_Startup_Time.txt
    ...    ELSE IF    ${state2test}==2
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    starting-openomci    ${list_onus}    ${timeStart}    print2console=True
    ...    output_file=ONU_Startup_Time.txt
    ...    ELSE IF    ${state2test}==3
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    discovery-mibsync-complete    ${list_onus}    ${timeStart}    print2console=True
    ...    output_file=ONU_Startup_Time.txt
    ...    ELSE IF    ${state2test}==4
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    initial-mib-downloaded    ${list_onus}    ${timeStart}    print2console=True
    ...    output_file=ONU_Startup_Time.txt
    ...    ELSE IF    ${state2test}==5
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    tech-profile-config-download-success    ${list_onus}    ${timeStart}    print2console=True
    ...    output_file=ONU_Startup_Time.txt
    ...    ELSE IF    ${state2test}==6
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    omci-flows-pushed    ${list_onus}    ${timeStart}    print2console=True
    ...    output_file=ONU_Startup_Time.txt
    ...    ELSE    Fail    The state to test (${state2test}) is not valid!

Do Onu Port Check
    [Documentation]    Check that all the UNI ports show up in ONOS
    Wait for Ports in ONOS      ${onos_ssh_connection}  ${num_onus}   BBSM

Set Tech Profile
    [Documentation]    This keyword set the passed TechProfile for the test
    [Arguments]    ${TechProfile}
	Log To Console    \nTechProfile:${TechProfile}
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd-0
    ${src}=    Set Variable    ${data_dir}/TechProfile-${TechProfile}.json
    ${dest}=    Set Variable    /tmp/flexpod.json
    ${command}    Catenate
    ...    /bin/sh -c 'cat    ${dest} | ETCDCTL_API=3 etcdctl put service/voltha/technology_profiles/XGS-PON/64'
    Copy File To Pod    ${namespace}    ${podname}    ${src}    ${dest}
    Exec Pod    ${namespace}    ${podname}    ${command}
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod    ${namespace}    ${podname}    ${commandget}

Remove Tech Profile
    [Documentation]    This keyword removes TechProfile
	Log To Console    \nTechProfile:${TechProfile}
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd-0
    ${command}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod    ${namespace}    ${podname}    ${command}
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod    ${namespace}    ${podname}    ${commandget}

Do Check Tech Profile
    [Documentation]    This keyword checks the loaded TechProfile
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd-0
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    ${result}=    Exec Pod    ${namespace}    ${podname}    ${commandget}
    ${num_gem_ports}=    Set Variable    1
    ${num_gem_ports}=    Set Variable If
    ...    "${techprofile}"=="default"   1
    ...    "${techprofile}"=="1T4GEM"    4
    ...    "${techprofile}"=="1T8GEM"    8
    @{resultList}    Split String    ${result}     separator=,
    ${num_of_count_matches}=    Get Match Count    ${resultList}    "num_gem_ports": ${num_gem_ports}
    ...    whitespace_insensitive=True
    ${num_of_expected_matches}=    Run Keyword If    "${techprofile}"=="default"    Evaluate    ${num_onus}
    ...    ELSE     Evaluate    ${num_onus}+1
    Run Keyword If    ${num_of_expected_matches}!=${num_of_count_matches}    Log To Console
    ...    \nTechProfile (${TechProfile}) not loaded correctly:${num_of_count_matches} of ${num_of_expected_matches}

Do Reconcile Onu Device
    [Documentation]    This keyword reconciles ONU device and check the state afterwards.
    ...    Following steps will be executed:
    ...    - ONU-Disable
    ...    - wait some seconds
    ...    - ONU-Enable
    ...    - wait some seconds
    ...    - optional: Check state = before disable
    # FOR    ${I}    IN RANGE    0    ${num_onus}
    ${I}=    Set Variable    0
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    20s    2s    Test Devices Disabled in VOLTHA    Id=${onu_device_id}
        Sleep    5s
        Enable Device    ${onu_device_id}
        Sleep    5s
        #check state
        Run Keyword If    ${reconcilestatetest}    Do Reconcile State Test    ${state2test}    ${src['onu']}
# END

Do Reconcile State Test
    [Documentation]    This keyword checks the passed state of the given onu.
    [Arguments]    ${state}    ${onu}
    Run Keyword If    ${state}==1
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
    ...    ${onu}    onu=True    onu_reason=activating-onu
    ...    ELSE IF    ${state}==2
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
    ...    ${onu}    onu=True    onu_reason=starting-openomci
    ...    ELSE IF    ${state}==3
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
    ...    ${onu}    onu=True    onu_reason=discovery-mibsync-complete
    ...    ELSE IF    ${state}==4
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ENABLED    ACTIVE    REACHABLE
    ...    ${onu}    onu=True    onu_reason=initial-mib-downloaded
    ...    ELSE IF    ${state}==5
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ENABLED    ACTIVE    REACHABLE
    ...    ${onu}    onu=True    onu_reason=tech-profile-config-download-success
    ...    ELSE IF    ${state}==6
    ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate Device    ENABLED    ACTIVE    REACHABLE
    ...    ${onu}    onu=True    onu_reason=omci-flows-pushed
    ...    ELSE    Fail    The state to test (${state}) is not valid!

Map State
    [Documentation]    This keyword converts the passed numeric value of a state to its state name.
    [Arguments]    ${statenumeric}
    ${statename}=    Set Variable If
	...    ${statenumeric}==1    activating-onu
    ...    ${statenumeric}==2    starting-openomci
    ...    ${statenumeric}==3    discovery-mibsync-complete
    ...    ${statenumeric}==4    initial-mib-downloaded
    ...    ${statenumeric}==5    tech-profile-config-download-success
    ...    ${statenumeric}==6    omci-flows-pushed
    [Return]    ${statename}
