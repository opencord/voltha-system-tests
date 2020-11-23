*** Settings ***
Library           grpc_robot.Dmi    WITH NAME    dmi1
Library           grpc_robot.Collections    WITH NAME    tools
Library           kafka_robot.KafkaClient    WITH NAME    kafka
Library           Collections
Library           BuiltIn

*** Variables ***

*** Keywords ***
Global Setup
    No Operation

Global Teardown
    [Documentation]     search for known/active devices and remove it from device manager
    dmi1.Connection Open    ${DEVICEMANAGER_IP}    ${DEVICEMANAGER_PORT}
    ${active_devices}=     Get Managed Devices   dmi1
    ${size}=    Get Length  ${active_devices}
    Run Keyword If   ${size} != ${0}   Stop Managing Devices    dmi1    ${active_devices}
    ${active_devices}=     Get Managed Devices   dmi1
    Should Be Empty     ${active_devices}
    dmi1.Connection Close

Get Managed Devices
    [Documentation]     search and return for known/active devices
    [Arguments]    ${lib_instance}
    ${name_active_olts}=    Create List
    ${response}=    Run Keyword   ${lib_instance}.Hw Management Service Get Managed Devices
    ${size}=    Get Length  ${response}
    Return From Keyword If   ${size} == ${0}   ${name_active_olts}
    ${devices}=     Get From Dictionary     ${response}     devices
    FOR     ${device}  IN  @{devices}
        ${name}=    Get From Dictionary    ${device}    name
        Append To List  ${name_active_olts}     ${name}
    END
    [Return]    ${name_active_olts}

Stop Managing Devices
    [Documentation]     remove given devices from device manager
    [Arguments]    ${lib_instance}  ${name_active_olts}
    FOR    ${device_name}    IN    @{name_active_olts}
        &{name}=    Evaluate    {'name':'${device_name}'}
        Run Keyword   ${lib_instance}.Hw Management Service Stop Managing Device    ${name}
    END

Search For Managed Devices And Stop Managing It
    [Documentation]     search for known/active devices and remove it from device manager
    [Arguments]    ${lib_instance}
    Run Keyword     ${lib_instance}.Connection Open    ${DEVICEMANAGER_IP}    ${DEVICEMANAGER_PORT}
    ${active_devices}=     Get Managed Devices   ${lib_instance}
    ${size}=    Get Length  ${active_devices}
    Run Keyword If   ${size} != ${0}   Stop Managing Devices      ${lib_instance}    ${active_devices}
    Run Keyword If   ${size} != ${0}    Fail    test case '${PREV_TEST_NAME}' failed!
    ${active_devices}=     Get Managed Devices   ${lib_instance}
    Should Be Empty     ${active_devices}
    Run Keyword 	 ${lib_instance}.Connection Close

Increment If Equal
    [Arguments]    ${condition_1}   ${condition_2}      ${value}
    ${value}=   Set Variable If  ${condition_1} == ${condition_2}
    ...   ${value+1}      ${value}
    [Return]    ${value}

Increment If Contained
    [Arguments]    ${message}   ${string}      ${value}
    ${hit}=   Run Keyword And Return Status    Should Contain   ${message}  ${string}
    ${value}=   Increment If Equal  ${hit}  ${True}  ${value}
    [Return]    ${value}

Start Managing Device
    [Documentation]     add a given device to the device manager
    [Arguments]    ${lib_instance}   ${olt_ip}    ${device_name}      ${check_result}=${True}
    ${dev_name}=    Convert To String    ${device_name}
    &{component}=    Evaluate    {'name':'${dev_name}', 'uri':{'uri':'${olt_ip}'}}
    ${response}=    Run Keyword   ${lib_instance}.Hw Management Service Start Managing Device    ${component}
    ${list}=    Get From List    ${response}    0
    Run Keyword If   ${check_result} == ${True}  Should Be Equal   ${list}[status]    OK_STATUS
    ${uuid}=    Get From Dictionary    ${list}    device_uuid
    [Return]  ${uuid}

Stop Managing Device
    [Documentation]     remove a given device from the device manager
    [Arguments]    ${lib_instance}   ${device_name}      ${check_result}=${True}
    &{name}=    Evaluate    {'name':'${device_name}'}
    ${response}=    Run Keyword   ${lib_instance}.Hw Management Service Stop Managing Device    ${name}
    Run Keyword If   ${check_result} == ${True}  Should Be Equal   ${response}[status]    OK_STATUS
