# Copyright 2017-present Open Networking Foundation
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


*** Settings ***
Documentation     Creates bbsim olt/onu and validates activataion
...               Assumes voltha-go, go-based onu/olt adapters, and bbsim are installed
...               voltctl and kubectl should be configured prior to running these tests
Library           OperatingSystem
Resource          ${CURDIR}/../../libraries/utils.robot
Resource          ${CURDIR}/../../variables/variables.robot
Suite Setup       Setup
Suite Teardown    Teardown

*** Variables ***
${server_ip}    localhost
${timeout}      60s
${num_onus}     1

*** Test Cases ***
Activate Device BBSIM OLT/ONU
    [Documentation]    Validate deployment ->
    ...    create and enable bbsim device ->
    ...    re-validate deployment
    [Tags]    activate
    #create/preprovision device
    ${rc}    ${device_id}=    Run and Return Rc and Output    voltctl device create -t openolt -H ${BBSIM_SERVICE}:${BBSIM_PORT}
    Should Be Equal As Integers    ${rc}    0
    #enable device
    ${rc}    ${output}=    Run and Return Rc and Output    voltctl device enable ${device_id}
    Should Be Equal As Integers    ${rc}    0
    #validate olt states
    Wait Until Keyword Succeeds    60s    5s    Validate Device    ${BBSIM_OLT_SN}    ENABLED    ACTIVE    REACHABLE
    #validate onu states
    Wait Until Keyword Succeeds    60s    5s    Validate Device    ${BBSIM_ONU_SN}    ENABLED    ACTIVE    REACHABLE

Validate OLT and AAA-Users in ONOS
    [Documentation]    Verifies the BBSIM-OLT device is activated in onos
    [Tags]    notready
    Wait Until Keyword Succeeds    ${timeout}    5s    BBSIM OLT Device in ONOS

Check EAPOL Flows in ONOS
    [Documentation]    Validates eapol flows for the onu are pushed from voltha
    [Tags]    notready
    Wait Until Keyword Succeeds    ${timeout}    5s    Verify Eapol Flows Added

Validate ONU Authenticated in ONOS
    [Documentation]    Validates onu is AUTHORIZED in ONOS as bbsim will attempt to authenticate
    [Tags]    notready
    Wait Until Keyword Succeeds    ${timeout}    5s    Verify Number of AAA-Users    ${number_of_onus}

Provision ONU Subscriber in ONOS
    [Documentation]    Through the olt-app in ONOS, execute 'volt-add-subscriber-access' and validate IP Flows
    [Tags]    notready

Validate DHCP Assignment in ONOS
    [Documentation]    After IP Flows are pushed to the device, BBSIM will start a dhclient for the ONU.
    [Tags]    notready

*** Keywords ***
Setup
    [Documentation]    Create HTTP Session with the ONOS Controller
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${server_ip}:8181    auth=${ONOS_AUTH}

Teardown
    [Documentation]    Delete all http sessions
    Delete All Sessions

BBSIM OLT Device in ONOS
    [Documentation]    Checks if bbsim olt has been connected to ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    @{serial_numbers}=    Create List
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
    \    ${sn}=    Get From Dictionary    ${value}    serial
    \    ${dpid}=    Get From Dictionary    ${value}    id
    Should Be Equal As Strings    ${dpid}    ${BBSIM_DEVICE_ID}
    Should Be Equal As Strings    ${sn}    ${BBSIM_OLT_SN}

Verify Eapol Flows Added
    [Arguments]    ${expected_onus}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS Command    flows -s -f ADDED | grep eapol | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_onus}

Verify Number of AAA-Users
    [Arguments]    ${expected_onus}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ${aaa_users}=    Execute ONOS Command    aaa-users | grep AUTHORIZED | wc -l
    Should Contain    ${aaa_users}    ${expected_onus}