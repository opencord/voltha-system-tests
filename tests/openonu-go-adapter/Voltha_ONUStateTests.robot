*** Settings ***
Documentation     Test states of ONU Go adapter with ATT workflows only (not for DT/TT workflow!)
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
Resource          Voltha_ONUUtilities.robot

*** Variables ***
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
# example: -v state2test:omci-flows-pushed
${state2test}    6
# test mode variable, can be passed via the command line too, valid values: SingleState, Up2State, SingleStateTime
# example: -v testmode:SingleStateTime
${testmode}    SingleState
# used tech profile, can be passed via the command line too, valid values: default (=1T1GEM), 1T4GEM, 1T8GEM
# example: -v techprofile:1T4GEM
${techprofile}    default
# flag debugmode is used, if true timeout calculation various, can be passed via the command line too
# example: -v debugmode:True
${debugmode}    False
# logging flag to enable Collect Logs, can be passed via the command line too
# example: -v logging:True
${logging}    False
# if True execution will be paused before clean up, only use in case of manual testing, do not use in ci pipeline!
# example: -v pausebeforecleanup:True
${pausebeforecleanup}    False
${data_dir}    ../data


*** Test Cases ***
ONU State Test
    [Documentation]    Validates the ONU Go adapter states
    [Tags]    sanityOnuGo    StateTestOnuGo
    [Setup]    Run Keywords    Start Logging    ONUStateTest
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #get olt serial number
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        ${olt_device_id}=    Get OLTDeviceID From OLT List    ${olt_serial_number}
        Enable Device    ${olt_device_id}
    END
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
    [Tags]    functionalOnuGo   CheckTechProfileOnuGo
    [Setup]    Start Logging    ONUCheckTechProfile
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Check Tech Profile
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUCheckTechProfile

Onu Port Check
    [Documentation]    Validates that all the UNI ports show up in ONOS
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    PortTestOnuGo
    [Setup]    Start Logging    ONUPortTest
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Onu Port Check
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUPortTest

Onu Flow Check
    [Documentation]    Validates the onu flows in ONOS and Voltha
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    FlowTestOnuGo    notreadyOnuGo
    [Setup]    Start Logging    ONUFlowTest
    Run Keyword If    '${onu_state}'=='omci-flows-pushed'    Do Onu Flow Check
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ONUFlowTest

Disable Enable Onu Device
    [Documentation]    Disables/enables ONU Device and check states
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    DisableEnableOnuGo
    [Setup]    Start Logging    DisableEnableONUDevice
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Disable Enable Onu Test
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    DisableEnableONUDevice

Reconcile Onu Device
    [Documentation]    Reconciles ONU Device and check state
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    ReconcileOnuGo
    [Setup]    Start Logging    ReconcileONUDevice
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Reconcile Onu Device
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    ReconcileONUDevice

Power Off Power On Onu Device
    [Documentation]    Power off and Power on of all ONU Devices and check state
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    PowerOffPowerOnOnuGo
    [Setup]    Start Logging    PowerOffPowerOnONUDevice
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Power Off Power On Onu Device
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    PowerOffPowerOnONUDevice

Soft Reboot Onu Device
    [Documentation]    Reboots softly all ONU Devices and check state
    ...    Assuming that ONU State Test was executed where all the ONUs are reached the expected state!
    [Tags]    functionalOnuGo    SoftRebootOnuGo
    [Setup]    Start Logging    SoftRebootONUDevice
    Run Keyword If    '${onu_state}'=='tech-profile-config-download-success' or '${onu_state}'=='omci-flows-pushed'
    ...    Do Soft Reboot Onu Device
    ...    ELSE    Pass Execution    ${skip_message}    skipped
    [Teardown]    Run Keywords    Run Keyword If    ${logging}    Collect Logs
    ...    AND    Stop Logging    SoftRebootONUDevice

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    ${LogInfo}=    Catenate
    ...    \r\nPassed arguments:
    ...    state2test:${state2test}, testmode:${testmode}, techprofile:${techprofile},
    ...    debugmode:${debugmode}, logging:${logging}, pausebeforecleanup:${pausebeforecleanup},
    Log    ${LogInfo}    console=yes
    Common Test Suite Setup
    # prepare skip message in yellow for console log
    ${skip}=  Evaluate  "\\033[33mSKIP\\033[0m"
    ${skipped}=  Evaluate  "\\033[33m${SPACE*14} ===> Test case above was skipped! <=== ${SPACE*15}\\033[0m"
    ${skip_message}    Catenate    ${skipped} | ${skip} |
    Set Suite Variable    ${skip_message}
    Run Keyword If   ${num_all_onus}>4    Calculate Timeout
    ${techprofile}=    Set Variable If    "${techprofile}"=="1T1GEM"    default    ${techprofile}
    Run Keyword If    "${techprofile}"=="default"   Log To Console    \nTechProfile:default (1T1GEM)
    ...    ELSE IF    "${techprofile}"=="1T4GEM"    Set Tech Profile    1T4GEM
    ...    ELSE IF    "${techprofile}"=="1T8GEM"    Set Tech Profile    1T8GEM
    ...    ELSE    Fail    The TechProfile (${techprofile}) is not valid!
    ${onos_ssh_connection}    Open ONOS SSH Connection    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
    Set Suite Variable  ${onos_ssh_connection}
    # map the passed onu state to reached and make it visible for test suite
    ${admin_state}    ${oper_status}    ${connect_status}    ${onu_state_nb}    ${onu_state}=
    ...    Map State    ${state2test}
    Set Suite Variable    ${admin_state}
    Set Suite Variable    ${oper_status}
    Set Suite Variable    ${connect_status}
    Set Suite Variable    ${onu_state_nb}
    Set Suite Variable    ${onu_state}
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
    # Create a list of olt ids (logical and device_id)
    ${olt_ids}    Create List
    FOR    ${I}    IN RANGE    0    ${num_olts}
        #create/preprovision device
        ${olt_device_id}=    Create Device    ${list_olts}[${I}][ip]    ${OLT_PORT}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${I}][sn]
        #validate olt states
        Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN    ${olt_device_id}
        Sleep    5s
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        ${olt}    Create Dictionary    device_id    ${olt_device_id}    logical_id    ${logical_id}
        ...    of_id    ${of_id}    sn    ${olt_serial_number}
        Append To List    ${olt_ids}    ${olt}
    END
    Set Global Variable    ${olt_ids}
    #--- old handling begin
    ##create/preprovision device
    #${olt_device_id}=    Create Device    ${olt_ip}    ${OLT_PORT}
    #Set Suite Variable    ${olt_device_id}
    ##validate olt states
    #Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
    #...    ${olt_device_id}
    #Sleep    5s
    #--- old handling end

Calculate Timeout
    [Documentation]    Calculates the timeout regarding num-onus in case of more than 4 onus
    ${timeout}    Fetch From Left    ${timeout}    s
    ${timeout}=    evaluate    ${timeout}+((${num_all_onus}-4)*30)
    ${timeout}=    Set Variable If    (not ${debugmode}) and (${timeout}>600)    600    ${timeout}
    ${timeout}=    Catenate    SEPARATOR=    ${timeout}    s
    Set Suite Variable    ${timeout}

Do ONU Up To State Test
    [Documentation]    This keyword performs Up2State Test
    ...    All states up to the passed have to be checked
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword If   ${onu_state_nb}>=1
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=activating-onu
        Run Keyword If   ${onu_state_nb}>=2
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=starting-openomci
        Run Keyword If   ${onu_state_nb}>=3
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVATING    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=discovery-mibsync-complete
        Run Keyword If   ${onu_state_nb}>=4
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=initial-mib-downloaded
        Run Keyword If   ${onu_state_nb}>=5
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=tech-profile-config-download-success
        Run Keyword If   ${onu_state_nb}>=6
        ...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
    END

Do ONU Single State Test
    [Documentation]    This keyword performs SingleState Test
    ...    Only the passed state has to be checked
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
        ...    Validate Device    ${admin_state}    ${oper_status}    ${connect_status}
        ...    ${src['onu']}    onu=True    onu_reason=${onu_state}
    END

Do ONU Single State Test Time
    [Documentation]    This keyword performs SingleState Test with calculate running time
    ...    Only the passed state has to be checked and the duration each single onu adapter needed
    ...    will be calculated and printed out
    #${ListfinishedONUs}    Create List
    #Set Global Variable    ${ListfinishedONUs}
    Create File    ONU_Startup_Time.txt    This file contains the startup times of all ONUs.
    ${list_onus}    Create List
    Build ONU SN List    ${list_onus}
    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms
    ...    Validate ONU Devices MIB State With Duration
    ...    ${onu_state}    ${list_onus}    ${timeStart}    print2console=True
    ...    output_file=ONU_Startup_Time.txt

Do Onu Port Check
    [Documentation]    Check that all the UNI ports show up in ONOS
    Wait for Ports in ONOS    ${onos_ssh_connection}    ${num_all_onus}    BBSM

Do Onu Flow Check
    [Documentation]    This keyword iterate all OLTs and performs Do Onu Flow Check Per OLT
    FOR    ${J}    IN RANGE    0    ${num_olts}
        ${olt_serial_number}=    Set Variable    ${list_olts}[${J}][sn]
        ${onu_count}=    Set Variable    ${list_olts}[${J}][onucount]
        ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS
        ...    ${olt_serial_number}
        Set Global Variable    ${of_id}
        ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get NNI Port in ONOS    ${of_id}
        Set Global Variable    ${nni_port}
        # Verify Default Meter in ONOS (valid only for ATT)
        Do Onu Flow Check Per OLT    ${of_id}    ${nni_port}    ${olt_serial_number}   ${onu_count}
    END

Do Onu Flow Check Per OLT
    [Documentation]    Check per OLT that all ONU flows show up in ONOS and Voltha
    [Arguments]    ${of_id}    ${nni_port}    ${olt_serial_number}    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
    END
    #check  for previous state is kept (normally omci-flows-pushed)
    Do Current State Test All Onus    ${state2test}

Set Tech Profile
    [Documentation]    This keyword set the passed TechProfile for the test
    [Arguments]    ${TechProfile}
    Log To Console    \nTechProfile:${TechProfile}
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
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
    ${podname}=    Set Variable    etcd
    ${command}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl del --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod    ${namespace}    ${podname}    ${command}
    ${commandget}    Catenate
    ...    /bin/sh -c 'ETCDCTL_API=3 etcdctl get --prefix service/voltha/technology_profiles/XGS-PON/64'
    Exec Pod    ${namespace}    ${podname}    ${commandget}

Do Check Tech Profile
    [Documentation]    This keyword checks the loaded TechProfile
    ${namespace}=    Set Variable    default
    ${podname}=    Set Variable    etcd
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
    ${num_of_expected_matches}=    Run Keyword If    "${techprofile}"=="default"    Evaluate    ${num_all_onus}
    ...    ELSE     Evaluate    ${num_all_onus}+1
    Run Keyword If    ${num_of_expected_matches}!=${num_of_count_matches}    Log To Console
    ...    \nTechProfile (${TechProfile}) not loaded correctly:${num_of_count_matches} of ${num_of_expected_matches}

Do Disable Enable Onu Test
    [Documentation]    This keyword disables/enables all onus and checks the states.
    [Arguments]    ${state2check}=${state2test}    ${checkstatebeforedisable}=True
    ...    ${state2checkafterdisable}=tech-profile-config-delete-success
    Run Keyword If    ${checkstatebeforedisable}    Do Current State Test All Onus    ${state2check}
    Do Disable Onu Device
    ${alternative_onu_reason}=    Set Variable If    '${state2checkafterdisable}'=='tech-profile-config-delete-success'
    ...    omci-flows-deleted    ${EMPTY}
    Do Current State Test All Onus    ${state2checkafterdisable}    alternativeonustate=${alternative_onu_reason}
    Log Ports
    #check no port is enabled in ONOS
    Wait for Ports in ONOS    ${onos_ssh_connection}    0    BBSM
    Do Enable Onu Device
    Do Current State Test All Onus    ${state2check}
    Log Ports    onlyenabled=True
    #check that all the UNI ports show up in ONOS again
    Wait for Ports in ONOS    ${onos_ssh_connection}    ${num_all_onus}    BBSM

Do Reconcile Onu Device
    [Documentation]    This keyword reconciles ONU device and check the state afterwards.
    ...    Following steps will be executed:
    ...    - restart openonu adaptor
    ...    - check openonu adaptor is ready again
    ...    - check previous state is kept
    ...    - ONU-Disable
    ...    - wait some seconds
    ...    - check for state omci-admin-lock
    ...    - ONU-Enable
    ...    - wait some seconds
    ...    - check for state onu-reenabled
    ...    - port check
    ${list_openonu_apps}   Create List    adapter-open-onu
    ${namespace}=    Set Variable    voltha
    ${adaptorname}=    Set Variable    open-onu
    Kill Adaptor    ${namespace}    ${adaptorname}
    Sleep    5s
    Wait For Pods Ready    ${namespace}    ${list_openonu_apps}
    Do Disable Enable Onu Test
    Do Onu Port Check

Do Power Off Power On Onu Device
    [Documentation]    This keyword power off/on all onus and checks the states.
    Do Power Off ONU Device
    Sleep    5s
    #Do Current State Test All Onus    stopping-openomci
    Do Current State Test All Onus    tech-profile-config-delete-success
    ...    ENABLED    DISCOVERED    UNREACHABLE    alternativeonustate=omci-flows-deleted
    Do Power On ONU Device
    Do Current State Test All Onus    ${state2test}

Do Soft Reboot Onu Device
    [Documentation]    This keyword reboots softly all onus and checks the states.
    ${namespace}=    Set Variable    voltha
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Reboot ONU    ${onu_device_id}   False
    END
    Run Keyword Unless    ${has_dataplane}    Do Current State Test All Onus    tech-profile-config-delete-success
    ...   ENABLED    DISCOVERED    REACHABLE    alternativeonustate=omci-flows-deleted
    Run Keyword Unless    ${has_dataplane}    Do Disable Enable Onu Test    checkstatebeforedisable=False
    ...    state2checkafterdisable=omci-admin-lock
    Run Keyword If    ${has_dataplane}    Do Current State Test All Onus    omci-flows-pushed
    Do Onu Port Check

Do Disable Onu Device
    [Documentation]    This keyword disables all onus.
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Disable Device    ${onu_device_id}
        Wait Until Keyword Succeeds    20s    2s    Test Devices Disabled in VOLTHA    Id=${onu_device_id}
    END

Do Enable Onu Device
    [Documentation]    This keyword enables all onus.
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Enable Device    ${onu_device_id}
    END

Do Power Off ONU Device
    [Documentation]    This keyword power off all onus.
    ${namespace}=    Set Variable    voltha
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${result}=    Exec Pod    ${namespace}    bbsim    bbsimctl onu shutdown ${src['onu']}
        Should Contain    ${result}    successfully    msg=Can not shutdown ${src['onu']}    values=False
    END
