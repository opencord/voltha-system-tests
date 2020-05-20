# SPDX-FileCopyrightText: 2019 - present Open Networking Foundation <info@opennetworking.org>
#
# SPDX-License-Identifier: Apache-2.0

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Lookup Pod That Owns Device
    [Arguments]    ${device_id}
    [Documentation]    Uses a utility script to lookup which RW Core has current ownership of an OLT
    ${rc}    ${pod}=    Run and Return Rc and Output
    ...    ../scripts/which_pod_owns_device.sh ${device_id}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${pod}

Lookup Deployment That Owns Device
    [Arguments]    ${device_id}
    [Documentation]    Uses a utility script to lookup which RW Core has current ownership of an OLT
    ${rc}    ${deploy}=    Run and Return Rc and Output
    ...    which_deployment_owns_device.sh ${device_id}
    Should Be Equal as Integers    ${rc}    0
    [Return]    ${deploy}

Restart VOLTHA Port Foward
    [Arguments]    ${name}
    [Documentation]    Uses a script to restart a kubectl port-forward
    ${cmd}	Catenate
    ...    ps e -ww -A |
    ...    grep _TAG=${name} |
    ...    grep -v grep |
    ...    awk '{printf(\"%s %s\\n\",$1,$5)}' |
    ...    grep -v bash | awk '{print $1}'
    ${rc}    ${pid}    Run And Return Rc And Output    ${cmd}
    Should Be Equal as Integers    ${rc}    0
    Run Keyword If    '${pid}' != ''    Run And Return Rc    kill -9 ${pid}
    Should Be Equal as Integers    ${rc}    0
