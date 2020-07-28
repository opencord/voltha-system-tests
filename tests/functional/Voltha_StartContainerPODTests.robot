# Copyright 2020 - present Open Networking Foundation
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
Documentation     Test various end-to-end scenarios
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
${timeout}        120s
${of_id}          0
${logical_id}     0
${has_dataplane}    True
${teardown_device}    False
${scripts}        ../../scripts
${with_onos}    True
${values_dir}    ../data
${kind_voltha_dir}    ~/kind-voltha
# Per-test logging on failure is turned off by default; set this variable to enable
${container_log_dir}    ${None}
${pausebeforesanity}    False
${onos_version}    ${EMPTY}

*** Test Cases ***

Sanity E2E Test for OLT/ONU on POD
    [Documentation]    Validates E2E Ping Connectivity and object states for the given scenario:
    ...    Validate successful authentication/DHCP/E2E ping for the tech profile that is used
    [Tags]    sanity    test1
    [Setup]    Run Keywords    Start Logging    SanityTest
    ...        AND             Setup
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    SanityTest
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Start voltha containers in a specific order and run sanity test
    [Documentation]    Starts voltha containers in a specific order and run sanity test
    ...    Assuming that test1 was executed where all the ONUs are authenticated/DHCP/pingable
    ...    Two starts of voltha container in specific orders are supported:
    ...    First order: voltha, voltha-adapters-simulated, voltha-adapters-open-olt, voltha-adapters-open-onu, onos
    ...    Second order: voltha-adapters-simulated, voltha-adapters-open-olt, voltha-adapters-open-onu, voltha, onos
    ...    For both orders following scenarios will be run
    ...    - Remove helm charts
    ...    - Restart Helm Charts in a specific order
    ...    - Restart Port Forwarding
    ...    - Repeat the sanity check
    [Tags]    functional    VOL-2008    StartVolthaContainers    notready
    [Setup]    Start Logging    StartVolthaContainers
    [Teardown]    Run Keywords    Collect Logs
    ...           AND             Stop Logging    StartVolthaContainers
	${list_order}    Create List    First    Second
    # Get simulated adpters are running
    ${contains_sim}=    Set Variable   False
	${container}    Get Container Dictionary    voltha
    FOR    ${key}    IN    @{container.keys()}
        ${contains_sim}=    Evaluate    "sim-voltha-adapter" in """${key}"""
        Exit For Loop IF    ${contains_sim}
    END
    # Prepare Helm Chart list
    ${list_voltha_apps}   Create List    ofagent    rw-core
    ${list_voltha_names}   Create List    voltha-voltha-ofagent    voltha-voltha-rw-core
	${voltha}    CreateDictionary    helmchart=voltha    namespace=voltha
    ...    apps=${list_voltha_apps}    names=${list_voltha_names}
    ${list_sim_apps}   Create List    adapter-simulated-olt    adapter-simulated-onu
    ${list_sim_names}   Create List    sim-voltha-adapter-simulated-olt    sim-voltha-adapter-simulated-onu
    ${sim}    CreateDictionary    helmchart=sim    namespace=voltha
    ...    apps=${list_sim_apps}    names=${list_sim_names}
    ${list_openolt_apps}   Create List    adapter-open-olt
    ${list_openolt_names}   Create List    open-olt-voltha-adapter-openolt
    ${open-olt}    CreateDictionary    helmchart=open-olt    namespace=voltha
    ...    apps=${list_openolt_apps}    names=${list_openolt_names}
    ${list_openonu_apps}   Create List    adapter-open-onu
    ${list_openonu_names}   Create List    open-onu-voltha-adapter-openonu
    ${open-onu}    CreateDictionary    helmchart=open-onu    namespace=voltha
    ...    apps=${list_openonu_apps}    names=${list_openonu_names}
    ${list_onos_apps}   Create List    onos-onos-classic
    ${list_onos_names}   Create List    onos-onos-classic
    ${onos}    CreateDictionary    helmchart=onos    namespace=default
    ...    apps=${list_onos_apps}    names=${list_onos_names}
    ${List_Helm_Charts}    Create List
    Run Keyword If    ${contains_sim}
    ...    Append To List    ${List_Helm_Charts}    ${voltha}    ${sim}    ${open-olt}    ${open-onu}    ${onos}
    ...    ELSE
    ...    Append To List    ${List_Helm_Charts}    ${voltha}    ${open-olt}    ${open-onu}    ${onos}
    # Start Loop over both orders
    FOR    ${order}    IN    @{list_order}
        Perfom Start voltha containers in a specific order    ${List_Helm_Charts}    ${order}    ${contains_sim}
        ...    ${with_onos}
    END

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup
    #Restore all ONUs
    #Run Keyword If    ${has_dataplane}    RestoreONUs    ${num_onus}
    #power_switch.robot needs it to support different vendor's power switch
    ${switch_type}=    Get Variable Value    ${web_power_switch.type}
    Run Keyword If  "${switch_type}"!=""    Set Global Variable    ${powerswitch_type}    ${switch_type}

Perfom Start voltha containers in a specific order
    [Arguments]    ${List_Helm_Charts}    ${order}    ${contains_sim}    ${with_onos}
    [Documentation]    Performes start ofvoltha containers in a specific order and run sanity test
    # Repeat Teardown Suite
    Run Keyword If    ${with_onos}
	...    Log    \r\nRepeat Teardown Suite (${order} order)...    console=yes
	Run Keyword If    ${with_onos}    Teardown Suite
    # Remove Helm Charts
    Log    \r\nRemove Helm Charts (${order} order)...    console=yes
	Remove Helm Charts    ${List_Helm_Charts}
    # Restart Helm Charts
    Log    \r\nRestart Helm Charts (${order} order)...    console=yes
    Restart Helm Charts    ${List_Helm_Charts}    ${order}    ${contains_sim}
    # Restart Port Forwarding
    Log    \r\nRestart Port Forwarding (${order} order)...    console=yes
    Restart Port Forwarding
    # Push ONOS Kafka Configuration
    Run Keyword If    ${with_onos}
	...    Log    \r\nPush ONOS Kafka Configuration (${order} order)...    console=yes
    Run Keyword If    ${with_onos}    Sleep    5s
    Run Keyword If    ${with_onos}
	...    Wait Until Keyword Succeeds    30s    3s    Push ONOS Kafka Configuration
    # Push ONOS DHCP L2 Relay Configuration
    Run Keyword If    ${with_onos}
	...    Log    \r\nPush ONOS DHCP L2 Relay Configuration (${order} order)...    console=yes
    Run Keyword If    ${with_onos}    Sleep    5s
    Run Keyword If    ${with_onos}
	...    Wait Until Keyword Succeeds    30s    3s    Push ONOS DHCP L2 Relay Configuration
    #Enable VOLTHA ONOS EAPOL provisioning
    Run Keyword If    ${with_onos}
	...    Log    \r\nEnable VOLTHA ONOS EAPOL provisioning (${order} order)...    console=yes
    Run Keyword If    ${with_onos}    Sleep    5s
    Run Keyword If    ${with_onos}
	...    Wait Until Keyword Succeeds    30s    3s    Enable VOLTHA ONOS EAPOL provisioning
    #Enable VOLTHA ONOS DHCP Provisioning
    Run Keyword If    ${with_onos}
	...    Log    \r\nEnable VOLTHA ONOS DHCP Provisioning (${order} order)...    console=yes
    Run Keyword If    ${with_onos}    Sleep    5s
    Run Keyword If    ${with_onos}
	...    Wait Until Keyword Succeeds    30s    3s    Enable VOLTHA ONOS DHCP Provisioning
    #Disable VOLTHA ONOS IGMP Provisioning
    Run Keyword If    ${with_onos}
	...    Log    \r\nDisable VOLTHA ONOS IGMP Provisioning (${order} order)...    console=yes
    Run Keyword If    ${with_onos}    Sleep    5s
    Run Keyword If    ${with_onos}
	...    Wait Until Keyword Succeeds    30s    3s    Disable VOLTHA ONOS IGMP Provisioning
    #Push ONOS SADIS Configuration
    Run Keyword If    ${with_onos}
	...    Log    \r\nPush ONOS SADIS Configuration (${order} order)...    console=yes
    Run Keyword If    ${with_onos}    Sleep    5s
    Run Keyword If    ${with_onos}
	...    Wait Until Keyword Succeeds    30s    3s    Push ONOS SADIS Configuration
    # Configure ONOS RADIUS Connection
    Run Keyword If    ${with_onos}
	...    Log    \r\nPush ONOS RADIUS Connection (${order} order)...    console=yes
    Run Keyword If    ${with_onos}    Sleep    5s
    Run Keyword If    ${with_onos}
	...    Wait Until Keyword Succeeds    30s    3s    Configure ONOS RADIUS Connection
	Log    \r\nSleep 10s (${order} order)...    console=yes
    Sleep    10s
    # Repeat Suite Setup
    Run Keyword If    ${with_onos}
	...    Log    \r\nRepeat Suite Setup (${order} order)...    console=yes
	Run Keyword If    ${with_onos}    Common Test Suite Setup
    # Repeat Setup
    Run Keyword If    ${with_onos}
	...    Log    \r\nRepeat Setup (${order} order)...    console=yes
	Run Keyword If    ${with_onos}    Setup
    Run Keyword If    ${pausebeforesanity}    Import Library    Dialogs
    Run Keyword If    ${pausebeforesanity}    Pause Execution    Press OK to continue with Sanity Check!
    # Repeat Sanity Test E2E Test for OLT/ONU on POD
    Log    \r\nRepeat Sanity Test E2E Test for OLT/ONU on POD (${order} order)...    console=yes
    Run Keyword If    ${has_dataplane}    Clean Up Linux
    Wait Until Keyword Succeeds    ${timeout}    2s    Perform Sanity Test

Remove Helm Charts
    [Arguments]    ${List_Helm_Charts}
    [Documentation]    Removes the helm charts
    FOR    ${helm_chart}    IN    @{List_Helm_Charts}
        ${helmchartname}    Get From Dictionary    ${helm_chart}    helmchart
        ${namespace}    Get From Dictionary    ${helm_chart}    namespace
        Run Keyword If    ${with_onos} or ('${helmchartname}'!='onos')    Remove VOLTHA Helm Charts    ${helmchartname}
    ...    ${namespace}
        ${list_names}    Get From Dictionary    ${helm_chart}    names
        Run Keyword If    ${with_onos} or ('${helmchartname}'!='onos')
        ...    Wait For Pods Not Exist    ${namespace}    ${list_names}
    END

Remove VOLTHA Helm Charts
    [Arguments]    ${name}    ${namespace}
    [Documentation]    Remove VOLTHA helm charts
    ${cmd}    Catenate    helm uninstall --no-hooks --namespace '${namespace}' '${name}'
    #${cmd}    Catenate    helm delete --no-hooks --purge '${name}'
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Restart Helm Charts
    [Arguments]    ${List_Helm_Charts}    ${order}    ${contains_sim}
    [Documentation]    Restarts the helm charts
    Run Keyword If    '${order}'=='First'    Restart Voltha
    Run Keyword If    ${contains_sim}    Restart Voltha Adapters Simulated
	Restart Voltha Adapters Open OLT
    Restart Voltha Adapters Open ONU
    Run Keyword If    '${order}'=='Second'    Restart Voltha
    Run Keyword If    ${with_onos}    Restart ONOS
    FOR    ${helm_chart}    IN    @{List_Helm_Charts}
        ${helmchartname}    Get From Dictionary    ${helm_chart}    helmchart
        ${namespace}    Get From Dictionary    ${helm_chart}    namespace
        ${list_apps}    Get From Dictionary    ${helm_chart}    apps
        Run Keyword If    ${with_onos} or ('${helmchartname}'!='onos')
        ...    Wait For Pods Ready    ${namespace}    ${list_apps}
    END

Restart Voltha Adapters Simulated
    [Documentation]    Restart Voltha Adapters Simulated helm chart
    ${cmd}	Catenate
    ...    helm install -f ${values_dir}/sim-adapter-values.yaml --create-namespace
    ...    --set services.etcd.service=etcd.default.svc --set services.etcd.port=2379
    ...    --set services.etcd.address=etcd.default.svc:2379 --set kafka_broker=kafka.default.svc:9092
    ...    --set services.kafka.adapter.service=kafka.default.svc --set services.kafka.adapter.port=9092
    ...    --set services.kafka.cluster.service=kafka.default.svc --set services.kafka.cluster.port=9092
    ...    --set services.kafka.adapter.address=kafka.default.svc:9092
    ...    --set services.kafka.cluster.address=kafka.default.svc:9092 --set defaults.log_level=WARN
    ...    --namespace voltha sim onf/voltha-adapter-simulated
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Restart Voltha Adapters Open OLT
    [Documentation]    Restart Voltha Adapters Open OLT helm chart
    ${cmd}	Catenate
    ...    helm install -f ${values_dir}/open-olt-values.yaml    --create-namespace
    ...    --set services.etcd.service=etcd.default.svc --set services.etcd.port=2379
    ...    --set services.etcd.address=etcd.default.svc:2379 --set kafka_broker=kafka.default.svc:9092
    ...    --set services.kafka.adapter.service=kafka.default.svc --set services.kafka.adapter.port=9092
    ...    --set services.kafka.adapter.address=kafka.default.svc:9092
    ...    --set services.kafka.cluster.service=kafka.default.svc --set services.kafka.cluster.port=9092
    ...    --set services.kafka.cluster.address=kafka.default.svc:9092 --set defaults.log_level=WARN
    ...    --namespace voltha open-olt onf/voltha-adapter-openolt
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Restart Voltha Adapters Open ONU
    [Documentation]    Restart Voltha Adapters Open ONU helm chart
    ${cmd}	Catenate
    ...    helm install -f ${values_dir}/open-onu-values.yaml    --set services.etcd.service=etcd.default.svc
    ...    --set services.etcd.port=2379 --set services.etcd.address=etcd.default.svc:2379
    ...    --set kafka_broker=kafka.default.svc:9092 --set services.kafka.adapter.service=kafka.default.svc
    ...    --set services.kafka.adapter.port=9092 --set services.kafka.adapter.address=kafka.default.svc:9092
    ...    --set services.kafka.cluster.service=kafka.default.svc --set services.kafka.cluster.port=9092
    ...    --set services.kafka.cluster.address=kafka.default.svc:9092 --set replicas.adapter_open_onu=1
    ...    --set defaults.log_level=WARN --namespace voltha open-onu onf/voltha-adapter-openonu
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Restart Voltha
    [Documentation]    Restart Voltha helm chart
    ${cmd}	Catenate
    ...    helm install -f ${values_dir}/voltha-values.yaml   --create-namespace --set therecanbeonlyone=true
    ...    --set therecanbeonlyone=true --set services.etcd.address=etcd.default.svc:2379
    ...    --set kafka_broker=kafka.default.svc:9092 --set services.kafka.adapter.address=kafka.default.svc:9092
    ...    --set services.kafka.cluster.address=kafka.default.svc:9092
    ...    --set 'services.controller[0].address=onos-onos-classic-0.onos-onos-classic-hs.default.svc:6653'
    ...    --set defaults.log_level=WARN --namespace voltha voltha onf/voltha
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0


Restart ONOS
    [Documentation]    Restart ONOS helm chart
    ${cmd}=    Run Keyword If    '${onos_version}'=='${EMPTY}'    Catenate
    ...    helm install -f ${values_dir}/onos-values.yaml
    ...    --create-namespace --set image.repository=voltha/voltha-onos,image.tag=master,replicas=1,atomix.replicas=0
    ...    --set defaults.log_level=WARN --namespace default onos onos/onos-classic
    ...    ELSE    Catenate
    ...    helm install -f ${values_dir}/minimal-values.yaml
    ...    --create-namespace --set image.repository=voltha/voltha-onos,image.tag=master,replicas=1,atomix.replicas=0
    ...    --set defaults.log_level=WARN --namespace default --version ${onos_version} onos onos/onos-classic
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Restart Port Forwarding
    [Documentation]    Restarts the VOLTHA port forwarding rules
    ${List_Tags}    Create List    etcd-minimal    voltha-voltha-api-minimal    kafka-minimal
    ...    onos-onos-classic-hs-minimal
    FOR    ${tag}    IN    @{List_Tags}
        Run Keyword If    ${with_onos} or ('${tag}'!='onos-onos-classic-hs-minimal')
        ...    Restart VOLTHA Port Forward    ${tag}
    END

Push ONOS Kafka Configuration
    [Documentation]    Pushes the ONOS kafka Configuration
    ${cmd}	Catenate
    ...    cd ~/kind-voltha;
    ...    curl -sSL --user karaf:karaf -w %\{http_code\} -X POST --fail -H Content-Type:application/json
    ...    http://127.0.0.1:8181/onos/v1/network/configuration/apps/org.opencord.kafka
    ...    --data '{"kafka":{"bootstrapServers":"kafka.default.svc:9092"}}'; cd -
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Push ONOS DHCP L2 Relay Configuration
    [Documentation]    Pushes the ONOS DHCP L2 Relay Configuration
    ${cmd}	Catenate
    ...    cd ~/kind-voltha;
    ...    curl -sSL --user karaf:karaf -w %\{http_code\} -X POST --fail -H Content-Type:application/json
    ...    http://127.0.0.1:8181/onos/v1/network/configuration/apps/org.opencord.dhcpl2relay
    ...    --data @onos-files/onos-dhcpl2relay.json; cd -
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Enable VOLTHA ONOS EAPOL provisioning
    [Documentation]    Pushes the ONOS EAPOL Configuration
    ${cmd}	Catenate
    ...    cd ~/kind-voltha;
    ...    curl -sSL --user karaf:karaf -w %\{http_code\} -X POST --fail -H Content-Type:application/json
    ...    http://127.0.0.1:8181/onos/v1/configuration/org.opencord.olt.impl.OltFlowService
    ...    --data '{"enableEapol":true}'; cd -
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Enable VOLTHA ONOS DHCP Provisioning
    [Documentation]    Pushes the ONOS OLT DHCP Configuration
    ${cmd}	Catenate
    ...    cd ~/kind-voltha;
    ...    curl -sSL --user karaf:karaf -w %\{http_code\} -X POST --fail -H Content-Type:application/json
    ...    http://127.0.0.1:8181/onos/v1/configuration/org.opencord.olt.impl.OltFlowService
    ...    --data '{"enableDhcpOnProvisioning":true,"enableDhcpV4":true}'; cd -
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Disable VOLTHA ONOS IGMP Provisioning
    [Documentation]    Pushes the ONOS IGMP Configuration
    ${cmd}	Catenate
    ...    cd ~/kind-voltha;
    ...    curl -sSL --user karaf:karaf -w %\{http_code\} -X POST --fail -H Content-Type:application/json
    ...    http://127.0.0.1:8181/onos/v1/configuration/org.opencord.olt.impl.OltFlowService
    ...    --data '{"enableIgmpOnProvisioning":false}'; cd -
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Push ONOS SADIS Configuration
    [Documentation]    Pushes the ONOS SADIS Configuration
    ${cmd}	Catenate
    ...    cd ~/kind-voltha;
    ...    curl -sSL --user karaf:karaf -w %\{http_code\} -X POST --fail -H Content-Type:application/json
    ...    http://127.0.0.1:8181/onos/v1/network/configuration/apps/org.opencord.sadis
    ...    --data @onos-files/onos-sadis-sample.json; cd -
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0

Configure ONOS RADIUS Connection
    [Documentation]    Configures the ONOS RADIUS Connection
    ${cmd}	Catenate
    ...    sed -e s/:RADIUS_SVC:/radius-freeradius.default.svc/g -e s/:RADIUS_PORT:/1812/
    ...    ${kind_voltha_dir}/onos-files/onos-aaa.json | curl --fail -sSL --user karaf:karaf -X POST
    ...    http://127.0.0.1:8181/onos/v1/network/configuration/apps/org.opencord.aaa
    ...    -H Content-type:application/json -d@-
    ${rc}    Run And Return Rc    ${cmd}
    Should Be Equal as Integers    ${rc}    0
