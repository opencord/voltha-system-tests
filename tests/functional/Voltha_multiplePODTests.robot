*** Settings ***
Documentation     Test various end-to-end scenarios with multiple BBSims
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

*** Test Cases ***
Sanity E2E Test for OLT/ONU on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanity    test1
    [Setup]    Run Keywords    Announce Message    START TEST SanityTest
    ...    AND    Start Logging    SanityTest
    ...    AND    Setup Test
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    [Teardown]    Run Keywords    Collect Logs
    ...    AND    Stop Logging    SanityTest
    ...    AND    Announce Message    END TEST SanityTest

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    # BBSim sanity test doesn't need these imports from other repositories
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/Subscriber.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/OLT.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/DHCP.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/Kubernetes.robot
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
    Check CLI Tools Configured
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${k8s_node_ip}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    ${num-olts}    Get Length    ${olts}
    ${num-olts}    Convert to String    ${num-olts}
    ${list-olts}    Create List
    FOR    ${I}    IN RANGE    0    ${num-olts}
		${ip}    Evaluate    ${olts}[${I}].get("ip")
		${user}    Evaluate    ${olts}[${I}].get("user")
		${pass}    Evaluate    ${olts}[${I}].get("pass")
		${serial_number}    Evaluate    ${olts}[${I}].get("serial")
		${olt}    Create Dictionary    ip    ${ip}    user    ${user}    pass
		...    ${pass}    sn    ${serial_number}
		Append To List    ${list-olts}    ${olt}
    END
    ${olt_ip}=    Evaluate    ${olts}[0].get("ip")
    ${olt_user}=    Evaluate    ${olts}[0].get("user")
    ${olt_pass}=    Evaluate    ${olts}[0].get("pass")
    ${olt_serial_number}=    Evaluate    ${olts}[0].get("serial")
    ${num_onus}=    Get Length    ${hosts.src}
    ${num_onus}=    Convert to String    ${num_onus}
    #send sadis file to onos
    ${sadis_file}=    Get Variable Value    ${sadis.file}
    Log To Console    \nSadis File:${sadis_file}
    Run Keyword Unless    '${sadis_file}' is '${None}'    Send File To Onos    ${sadis_file}    apps/
    Set Suite Variable    ${num_onus}
    Set Suite Variable    ${num-olts}
    Set Suite Variable    ${list-olts}
    Set Suite Variable    ${olt_serial_number}
    Set Suite Variable    ${olt_ip}
    Set Suite Variable    ${olt_user}
    Set Suite Variable    ${olt_pass}
    Set Suite Variable    ${k8s_node_ip}
    Set Suite Variable    ${k8s_node_user}
    Set Suite Variable    ${k8s_node_pass}
    @{container_list}=    Create List    adapter-open-olt    adapter-open-onu    voltha-api-server    voltha-ro-core    voltha-rw-core-11
    ...    voltha-rw-core-12    voltha-ofagent
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
    FOR    ${I}    IN RANGE    0    ${num_bbsims}
		${olt_device_id}=    Create Device    ${list-olts}[${I}][ip]    ${OLT_PORT}
		Set Suite Variable    ${olt_device_id}
		#validate olt states
		Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
		...    ${EMPTY}    ${olt_device_id}
		Sleep    5s
		Enable Device    ${olt_device_id}
		Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
		...    ${olt_serial_number}
		${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
		Set Suite Variable    ${logical_id}
    END

Clear All Devices Then Create New Device
    [Documentation]    Remove any devices from VOLTHA and ONOS
    # Remove all devices from voltha and nos
    Delete All Devices and Verify
    # Execute normal test Setup Keyword
    Setup
