# Copyright 2017 - present Open Networking Foundation
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
Documentation     Test various failure scenarios
Suite Setup       Common Test Suite Setup
Test Setup        Setup
Test Teardown     Teardown
#Suite Teardown    Teardown Suite
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
Resource          ../../libraries/power_switch.robot

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
Verify restart ofagent container after VOLTHA is operational
    [Documentation]    Restart ofagent container after VOLTHA is operational.
    ...    Please note this test case should be run before the restart of other containers.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functional   VOL-2409   ofagentRestart   notready
    [Setup]    Run Keywords    Announce Message    START TEST ofagentRestart
    ...        AND             Start Logging    ofagentRestart
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ofagentRestart
    ...           AND             Announce Message    END TEST ofagentRestart
    # Performing Sanity Test to make sure subscribers are all AUTH+DHCP and pingable
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    ${waitforRestart}    Set Variable    120s
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Restart Pod    ${NAMESPACE}    ofagent
    Sleep    60s
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ofagent    ${NAMESPACE}
    ...    Running
    Repeat Sanity Test
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}

Verify restart openolt-adapter container after VOLTHA is operational
    [Documentation]    Restart openolt-adapter container after VOLTHA is operational.
    ...    Prerequisite : ONUs are authenticated and pingable.
    [Tags]    functional   VOL-1958   RestartPods
    [Setup]    Run Keywords    Announce Message    START TEST RestartPods
    ...        AND             Start Logging    RestartPods
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RestartPods
    ...           AND             Announce Message    END TEST RestartPods
    ${waitforRestart}    Set Variable    120s
    # Remove the Sanity Check after enabling first failure test (OLT Adapter Test)
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countBforRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    ${podName}    Set Variable     adapter-open-olt
    Restart Pod    ${NAMESPACE}    ${podName}
    Wait Until Keyword Succeeds    ${waitforRestart}    2s    Validate Pod Status    ${podName}    ${NAMESPACE}
    ...    Running
    Repeat Sanity Test
    ${podStatusOutput}=    Run    kubectl get pods -n ${NAMESPACE}
    Log    ${podStatusOutput}
    ${countAfterRestart}=    Run    kubectl get pods -n ${NAMESPACE} | grep Running | wc -l
    Should Be Equal As Strings    ${countAfterRestart}    ${countBforRestart}
    Log to console    Pod ${podName} restarted and sanity checks passed successfully

Check ONU adapter crash not forcing authentication again
    [Documentation]    After ONU adapter restart, checks wpa log for 'authentication started'
    ...    message count to make sure auth not started again and validates EAP status and ping.
    ...    Assuming that test1 or sanity was executed where all the ONUs are authenticated/DHCP/pingable
    [Tags]    functional    ONUAdaptCrash    notready
    [Setup]    Run Keywords    Announce Message    START TEST ONUAdaptCrash
    ...        AND             Start Logging    ONUAdaptCrash
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    ONUAdaptCrash
    ...           AND             Announce Message    END TEST ONUAdaptCrash
    @{before_list}=    Create List
    @{after_list}=    Create List
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${before}=    Run Keyword If    ${has_dataplane}    Check Remote File Contents For WPA Logs
        ...    True    /tmp/wpa.log    authentication started    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Append To List    ${before_list}    ${before}
    END
    Wait Until Keyword Succeeds    ${timeout}    15s    Restart Pod    ${NAMESPACE}    adapter-open-onu
    Wait Until Keyword Succeeds    ${timeout}    2s    Validate Pod Status    ${podName}    ${NAMESPACE}
    ...    Running
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s    Get ONU Port in ONOS    ${src['onu']}
        ...    ${of_id}
        ${after}=    Run Keyword If    ${has_dataplane}    Check Remote File Contents For WPA Logs
        ...    True    /tmp/wpa.log    authentication started    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Append To List    ${after_list}    ${after}
        ${output}=    Run Keyword If    ${has_dataplane}    Login And Run Command On Remote System
        ...    wpa_cli status | grep SUCCESS    ${src['ip']}    ${src['user']}    ${src['pass']}
        ...    ${src['container_type']}    ${src['container_name']}
        Run Keyword If    ${has_dataplane}    Should Contain    ${output}    SUCCESS
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s    Check Ping
        ...    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}    ${src['ip']}    ${src['user']}
        ...    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END
    Lists Should Be Equal    ${after_list}    ${before_list}
    Log    ${after_list}
    Log    ${before_list}
    Run Keyword and Ignore Error    Collect Logs

Verify ONU after rebooting physically
    [Documentation]    Test the ONU funcaionality by physically turning on/off ONU.
    ...    Prerequisite : Subscriber are authenticated/DHCP/pingable state
    [Tags]    functional   VOL-2488    PowerSwitch    notready
    [Setup]    Run Keywords    Announce Message    START TEST PowerSwitch
    ...        AND             Start Logging    PowerSwitch
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    PowerSwitch
    ...           AND             Announce Message    END TEST PowerSwitch
    Start Log Capture    PowerSwitch    ${container_log_dir}
    Power Switch Connection Suite    ${web_power_switch.ip}    ${web_power_switch.user}    ${web_power_switch.password}
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Disable Switch Outlet    ${src['power_switch_port']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}

        Enable Switch Outlet    ${src['power_switch_port']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s    Validate Device
        ...    ENABLED    ACTIVE    REACHABLE    ${src['onu']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    60s    2s
        ...    Check Ping    True    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
    END

ONU Reboot
    [Documentation]    Reboot ONU and verify that ONU comes up properly
    [Tags]    VOL-1957    RebootONU   notready
    [Setup]    Run Keywords    Announce Message    START TEST RebootONU
    ...        AND             Start Logging    RebootONU
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    RebootONU
    ...           AND             Announce Message    END TEST RebootONU
    FOR    ${I}    IN RANGE    0    ${num_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Reboot ONU    ${onu_device_id}   ${src}   ${dst}
        Verify ping is succesful except for given device     ${num_onus}    ${onu_device_id}
        Run Keyword If    ${has_dataplane}    Clean Up Linux
        #Check after reboot that ONUs are active, authenticated/DHCP/pingable
        Perform Sanity Test
    END
