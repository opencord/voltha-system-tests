*** Settings ***
Documentation     Test states of ONU Go adapter
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite
Test Setup
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
${timeout}        60s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${external_libs}    True
${teardown_device}    False
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}
# state to test variable, can be passed via the command line too
${state2test}    100
${testmode}    SingleState

*** Test Cases ***
ONU State Test
    [Documentation]    Validates the ONU Go adapter states
    [Tags]    statetest
    [Setup]    Run Keywords    Announce Message    START TEST ONUStateTest
    ...    AND    Start Logging    ONUStateTest
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    FOR    ${I}    IN RANGE    0    ${num_olts}
		${olt_ip}=    Evaluate    ${olts}[${I}].get("ip")
		${olt_user}=    Evaluate    ${olts}[${I}].get("user")
		${olt_pass}=    Evaluate    ${olts}[${I}].get("pass")
		${olt_serial_number}=    Evaluate    ${olts}[${I}].get("serial")
		${src}=    Evaluate    ${hosts}[${I}].get("src")
		${dst}=    Evaluate    ${hosts}[${I}].get("dst")
		Set Suite Variable    ${olt_serial_number}
		Set Suite Variable    ${olt_ip}
		Set Suite Variable    ${olt_user}
		Set Suite Variable    ${olt_pass}
		Enable Device    ${olt_device_id}
    	Run Keyword If    "${testmode}"=="SingleState"    Do ONU Single State Test    ${src}    ${dst}
    	Run Keyword If    "${testmode}"=="Up2State"    Do ONU Up To State Test    ${src}    ${dst}
	END
    [Teardown]    Run Keywords    Collect Logs
    ...    AND    Stop Logging    ONUStateTest
    ...    AND    Announce Message    END TEST ONUStateTest

*** Keywords ***
Setup Suite
    [Documentation]    Setup the test suite
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${ONOS_REST_IP}=    Get Environment Variable    ONOS_REST_IP    ${k8s_node_ip}
    ${ONOS_SSH_IP}=     Get Environment Variable    ONOS_SSH_IP     ${k8s_node_ip}
    Set Global Variable    ${ONOS_REST_IP}
    Set Global Variable    ${ONOS_SSH_IP}
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
    Check CLI Tools Configured
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${ONOS_REST_IP}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    ${num_olts}    Get Length    ${olts}
    ${num_olts}    Convert to String    ${num_olts}
    ${list_olts}    Create List
    FOR    ${I}    IN RANGE    0    ${num_olts}
		${ip}    Evaluate    ${olts}[${I}].get("ip")
		${user}    Evaluate    ${olts}[${I}].get("user")
		${pass}    Evaluate    ${olts}[${I}].get("pass")
		${serial_number}    Evaluate    ${olts}[${I}].get("serial")
		${olt}    Create Dictionary    ip    ${ip}    user    ${user}    pass
		...    ${pass}    sn    ${serial_number}
		Append To List    ${list_olts}    ${olt}
    END
    ${olt_ip}=    Evaluate    ${olts}[0].get("ip")
    ${olt_user}=    Evaluate    ${olts}[0].get("user")
    ${olt_pass}=    Evaluate    ${olts}[0].get("pass")
    ${olt_serial_number}=    Evaluate    ${olts}[0].get("serial")
    ${num_onus}=    Evaluate    ${hosts}[0].get("src")
    ${num_onus}=    Get Length    ${num_onus}
    ${num_onus}=    Convert to String    ${num_onus}
    #send sadis file to onos
    ${sadis_file}=    Get Variable Value    ${sadis.file}
    Log To Console    \nSadis File:${sadis_file}
    Run Keyword Unless    '${sadis_file}' is '${None}'    Send File To Onos    ${sadis_file}    apps/
    Set Suite Variable    ${num_onus}
    Set Suite Variable    ${num_olts}
    Set Suite Variable    ${list_olts}
    Set Suite Variable    ${olt_serial_number}
    Set Suite Variable    ${olt_ip}
    Set Suite Variable    ${olt_user}
    Set Suite Variable    ${olt_pass}
    Set Suite Variable    ${k8s_node_ip}
    Set Suite Variable    ${k8s_node_user}
    Set Suite Variable    ${k8s_node_pass}
    @{container_list}=    Create List    adapter-open-olt    adapter-open-onu    voltha-api-server
    ...    voltha-ro-core    voltha-rw-core-11    voltha-rw-core-12    voltha-ofagent
    Set Suite Variable    ${container_list}
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}

Setup Test
    [Documentation]    Pre-test Setup
    #test for empty device list
    Test Empty Device List
    Sleep    60s
    #create/preprovision device
    #read all bbsims
    ${rc}    ${num_bbsims}    Run And Return Rc And Output    kubectl get pod -n voltha | grep bbsim | wc -l
    Should Be Equal As Integers    ${rc}    0
    Should Not Be Empty    ${num_bbsims}
    Should Not Be Equal As Integers    ${num_bbsims}    0
	Run Keyword Unless    ${has_dataplane}    Set Suite Variable    ${num_olts}    ${num_bbsims}
    FOR    ${I}    IN RANGE    0    ${num_olts}
		${olt_device_id}=    Create Device    ${list_olts}[${I}][ip]    ${OLT_PORT}
		Set Suite Variable    ${olt_device_id}
		#validate olt states
		Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
		...    ${olt_device_id}
		Sleep    5s
    END

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup

Do ONU Up To State Test
    [Arguments]    ${host_src}    ${host_dst}
    [Documentation]    This keyword performs Up2State Test
    ...    All states up to the passed have to be checked
	${num_onus}=    Get Length    ${host_src}
	${num_onus}=    Convert to String    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_onus}
		${src}=    Set Variable    ${host_src[${I}]}
		${dst}=    Set Variable    ${host_dst[${I}]}
		Run Keyword If   ${state2test}>=1
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVATING    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=activating-onu
		Run Keyword If   ${state2test}>=2
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVATING    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=starting-openomci
		Run Keyword If   ${state2test}>=3
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVATING    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=discovery-mibsync-complete
		Run Keyword If   ${state2test}>=4
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVE    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=initial-mib-downloaded
		Run Keyword If   ${state2test}>=5
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVE    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=tech-profile-config-download-success
		Run Keyword If   ${state2test}>=6
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVE    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
	END

Do ONU Single State Test
    [Arguments]    ${host_src}    ${host_dst}
    [Documentation]    This keyword performs SingleState Test
    ...    Only the passed state has to be checked
	${num_onus}=    Get Length    ${host_src}
	${num_onus}=    Convert to String    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_onus}
		${src}=    Set Variable    ${host_src[${I}]}
		${dst}=    Set Variable    ${host_dst[${I}]}
		Run Keyword If   ${state2test}==1 
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVATING    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=activating-onu
		Run Keyword If   ${state2test}==2
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVATING    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=starting-openomci
		Run Keyword If   ${state2test}==3
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVATING    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=discovery-mibsync-complete
		Run Keyword If   ${state2test}==4
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVE    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=initial-mib-downloaded
		Run Keyword If   ${state2test}==5
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVE    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=tech-profile-config-download-success
		Run Keyword If   ${state2test}==6
		...    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    50ms    Validate Device
		...    ENABLED    ACTIVE    REACHABLE
		...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
	END
