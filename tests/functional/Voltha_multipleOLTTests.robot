*** Settings ***
Documentation     Test various end-to-end scenarios with multiple OLTs
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
${teardown_device}    True
${scripts}        ../../scripts
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}

*** Test Cases ***
Sanity E2E Test for OLTs/ONUs on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanityMultiOLT
    [Setup]    Run Keywords    Start Logging    SanityMultiOLT
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
        Wait Until Keyword Succeeds    ${timeout}    2s    Do Sanity Test    ${src}    ${dst}
    END
    [Teardown]    Run Keywords    Collect Logs
    ...    AND    Stop Logging    SanityTest

*** Keywords ***
Setup Suite
    [Documentation]    Setup the test suite
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    %{VOLTCONFIG}
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
        ${olt_device_id}=    Run Keyword If    "${list_olts}[${I}][type]" == "${None}"
        ...    Create Device    ${list_olts}[${I}][ip]    ${OLT_PORT}
        ...    ELSE    Create Device    ${list_olts}[${I}][ip]    ${OLT_PORT}    ${list_olts}[${I}][type]
        Set Suite Variable    ${olt_device_id}
        #validate olt states
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    PREPROVISIONED    UNKNOWN    UNKNOWN
        ...    ${olt_device_id}
        Sleep    5s
        Enable Device    ${olt_device_id}
        Wait Until Keyword Succeeds    ${timeout}    5s    Validate OLT Device    ENABLED    ACTIVE    REACHABLE
        ...    ${olt_serial_number}
        ${logical_id}=    Get Logical Device ID From SN    ${olt_serial_number}
        Set Suite Variable    ${logical_id}
    END

Do Sanity Test
    [Arguments]    ${host_src}    ${host_dst}
    [Documentation]    This keyword performs Sanity Test Procedure
    ...    Sanity test performs authentication, dhcp and pings for all the ONUs given for the POD
    ...    This keyword can be used to call in any other tests where sanity check is required
    ...    and avoids duplication of code.
    ${of_id}=    Wait Until Keyword Succeeds    ${timeout}    15s    Validate OLT Device in ONOS    ${olt_serial_number}
    Set Global Variable    ${of_id}
    ${nni_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Get NNI Port in ONOS    ${of_id}
    Set Global Variable    ${nni_port}
    ${num_onus}=    Get Length    ${host_src}
    ${num_onus}=    Convert to String    ${num_onus}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${host_src[${I}]}
        ${dst}=    Set Variable    ${host_dst[${I}]}
        Run Keyword and Ignore Error    Collect Logs
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}
        # Check ONU port is Enabled in ONOS
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds   120s   2s
        ...    Verify ONU Port Is Enabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify EAPOL flows are added for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify Eapol Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify ONU state in voltha
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE
        ...    ${src['onu']}    onu=True    onu_reason=omci-flows-pushed
        # Perform Authentication
        ${wpa_log}=    Run Keyword If    ${has_dataplane}    Catenate    SEPARATOR=.
        ...    /tmp/wpa    ${src['dp_iface_name']}    log
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate Authentication    True
        ...    ${src['dp_iface_name']}    wpa_supplicant.conf    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}    ${wpa_log}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Verify ONU in AAA-Users    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2
        ...    Execute ONOS CLI Command    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}
        ...    volt-add-subscriber-access ${of_id} ${onu_port}
        # Verify that no pending flows exist for the ONU port
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Verify No Pending Flows For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        # Verify subscriber access flows are added for the ONU port
        # Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        # ...    Verify Subscriber Access Flows Added For ONU    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${of_id}
        # ...    ${onu_port}    ${nni_port}    ${src['c_tag']}    ${src['s_tag']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure    Validate DHCP and Ping    True
        ...    True    ${src['dp_iface_name']}    ${src['s_tag']}    ${src['c_tag']}    ${dst['dp_iface_ip_qinq']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ...    ${dst['dp_iface_name']}    ${dst['ip']}    ${dst['user']}    ${dst['pass']}    ${dst['container_type']}
        ...    ${dst['container_name']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Validate Subscriber DHCP Allocation    ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${onu_port}
        Run Keyword and Ignore Error    Get Device Output from Voltha    ${onu_device_id}
        Run Keyword and Ignore Error    Collect Logs
    END

