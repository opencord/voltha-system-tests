*** Settings ***
Documentation     Library for testing dmi interface (hw_management_service.proto)
Library           Process
Library           grpc_robot.Dmi    WITH NAME    dmi1
Library           grpc_robot.Collections    WITH NAME    tools
Library           kafka_robot.KafkaClient    WITH NAME    kafka
Library           Collections
Library           BuiltIn
Library           ../../libraries/utility.py    WITH NAME    utility
Resource          ../../libraries/dmi-basics.robot
Variables         ../../variables/variables.py
Suite Setup       Suite Setup
Suite Teardown    Suite Teardown

*** Variables ***
${DEVICEMANAGER_IP}    ${GIVEN_DM_IP}
${DEVICEMANAGER_PORT}    ${GIVEN_DM_PORT}
${OLT_IP}         ${GIVEN_OLT_IP}

*** Test Cases ***
Start and Stop Managing Device In Device Manager
    [Documentation]     add/remove device in device manager (testcase is done by Suite Setup and Suite Teardown)
    [Tags]  sanityDMI  functionalDMI  EnableOltDMI
    # this tescase exist, to have the possiblity to check only the Start-/Stop-ManagingDevice
    # can be run via adding parameter ("-t add and remove device in device manager") to the robot call!
    No Operation

Get Inventory Data
    [Documentation]  get physical inventory data from OLT
    [Tags]  functionalDMI  GetInventoryDataDMI
    &{PhyInvReq}=  Evaluate  {'device_uuid':${suite_device_uuid}}
    ${inventory}=  dmi1.Hw Management Service Get Physical Inventory  ${PhyInvReq}
    ${result}=  Get From List  ${inventory}  0
    Should Be Equal  ${result}[status]  OK_STATUS
    FOR  ${component}  IN  @{dm_components}
        Log  ${component}
        Check Physical Inventory  ${inventory}  ${component}
    END

Get Configurable Component Inventory Info
    [Documentation]  get physical component info of all hw in given yaml file
    [Tags]  functionalDMI  GetConfigurableComponentInventoryInfoDMI
    &{PhyInvReq}=  Evaluate    {'device_uuid':${suite_device_uuid}}
    ${inventory}=  dmi1.Hw Management Service Get Physical Inventory    ${PhyInvReq}
    ${result}=  Get From List  ${inventory}  0
    Should Be Equal  ${result}[status]    OK_STATUS
    FOR  ${component}  IN  @{dm_components}
        Log  ${component}
        ${component_name}=  Convert To String  ${component['name']}
        ${component_uuid}=  Get Component Uuid From Inventory  ${inventory}  ${component_name}
        ${hwComInfoReq}=  Evaluate
        ...  {'device_uuid':${suite_device_uuid}, 'component_uuid':${component_uuid}, 'component_name':'${component_name}'}
        ${hwComInfoRes}=  dmi1.Hw Management Service Get Hw Component Info  ${hwComInfoReq}
        ${hwComInfoRes}=  Get From List  ${hwComInfoRes}  0
        ${status}=  Get From Dictionary  ${hwComInfoRes}  status
        Should Be Equal  ${status}  OK_STATUS
        ${res_component}=  Get From Dictionary  ${hwComInfoRes}  component
        ${value_name}=  Get From Dictionary  ${res_component}  name
        Should be Equal  ${value_name}  ${component_name}
        Set Component Inventory Info Unimplemented  ${suite_device_uuid}  ${component_uuid}  ${component_name}  new-value
    END

Get Loggable Entities
    [Documentation]  get the loggable entities of the device
    [Tags]  functionalDMI  GetLoggableEntitiesDMI
    ${loggable_entities}=  Loggable Entities  dmi1  ${suite_device_uuid}
    ${size_loggable_entities}=  Get Length  ${loggable_entities}
    Should Be True  ${size_loggable_entities} > 5

Set Get Logging Endpoint
    [Documentation]  set/get the loggable endpoint of a device
    [Tags]  functionalDMI  SetGetLoggingEndpointDMI
    ${defined_endpoint}=  Set Variable  127.0.0.1
    ${defined_protocol}=  Set Variable  udp
    ${set_endpoint}=  Evaluate  
    ...  {'device_uuid':${suite_device_uuid}, 'logging_endpoint': '${defined_endpoint}', 'logging_protocol': '${defined_protocol}'}
    ${response}=  dmi1.Hw Management Service Set Logging Endpoint  ${set_endpoint}
    ${state}=  Get From Dictionary  ${response}  status
    Should Be Equal  ${state}  OK_STATUS
    # now the new logging endpoint and protocol should be set!
    ${uuid}=  Evaluate  {'uuid':${suite_device_uuid}}
    ${log_endpoint}=   dmi1.Hw Management Service Get Logging Endpoint  ${uuid}
    ${state}=  Get From Dictionary  ${log_endpoint}  status
    Should Be Equal  ${state}  OK_STATUS
    ${get_endpoint}=  Get From Dictionary  ${log_endpoint}  logging_endpoint
    ${get_protocol}=  Get From Dictionary  ${log_endpoint}  logging_protocol
    Should Be Equal  ${get_endpoint}  ${defined_endpoint}
    Should Be Equal  ${get_protocol}  ${defined_protocol}
    # remove logging endpoint
    ${set_endpoint}=  Evaluate  
    ...  {'device_uuid':${suite_device_uuid}, 'logging_endpoint': '', 'logging_protocol': '${defined_protocol}'}
    ${response}=  dmi1.Hw Management Service Set Logging Endpoint  ${set_endpoint}
    ${state}=  Get From Dictionary  ${response}  status
    Should Be Equal  ${state}  OK_STATUS

#Set Get LogLevel
#    [Documentation]  set and get the log level of a device
#    [Tags]  functionalDMI  SetGetLogLevelDMI  skipped
#    ${loggable_entities}=  Get X Loggable Entities  dmi1  ${suite_device_uuid}  10
#    ${list_log_entities}=  Create List  ${loggable_app}
#    ${loglvl_request}=  Evaluate  {'device_uuid':${suite_device_uuid}, 
#    ${response}=   dmi1.Hw Management Service Set Log Level  dmi1  ${loglvl_request}

*** Keywords ***
Suite Setup
    [Documentation]  start a managed device in the device manager
    dmi1.Connection Open  ${DEVICEMANAGER_IP}  ${DEVICEMANAGER_PORT}
    ${suite_device_uuid}=  Start Managing Device  dmi1    ${OLT_IP}    BBSim-BBSIM_OLT_0
    ${suite_device_name}=  Evaluate    {'name':'BBSim-BBSIM_OLT_0'}
    Set Suite Variable  ${suite_device_uuid}
    Set Suite Variable  ${suite_device_name}

Suite Teardown
    [Documentation]   stop a managed device in device manager
    Stop Managing Device   dmi1    BBSim-BBSIM_OLT_0
    dmi1.Connection Close
    Search For Managed Devices And Stop Managing It     dmi1

Check Physical Inventory
    [Documentation]  This keyword checks the passed inventory data
    [Arguments]  ${inventory}  ${component}
    FOR  ${inventory_element}  IN  @{inventory}
        log    ${inventory_element}
        Check Inventory Element  ${inventory_element}  ${component}
    END

Check Inventory Element
    [Documentation]    This keyword checks the passed element data
    [Arguments]  ${inventory_element}  ${component}
    FOR  ${component_element}  IN  @{component['elements']}
        log    ${component_element}
        ${result}=  utility.check_Inventory_Element  ${inventory_element}  ${component['name']}  ${component_element['element']}
        ...   ${component_element['value']}
        Should be True  ${result}
    END

Get Component Uuid From Inventory
    [Documentation]  This keyword delivers component-uuid from inventory of passed component-name
    [Arguments]  ${inventory}  ${component_name}
    FOR  ${element}  IN  @{inventory}
        Log  ${element}
        ${component_uuid}=  utility.get_uuid_from_Inventory_Element  ${element}  ${component_name}
    END
    Should Not Be Equal  ${None}  ${component_uuid}
    [Return]    ${component_uuid}

Loggable Entities
    [Documentation]  get the loggable entities of a device
    [Arguments]  ${lib_instance}  ${uuid}  ${with_check}=${TRUE}
    ${device_uuid}=  Evaluate  {'device_uuid':${uuid}}
    ${response}=  Run Keyword  ${lib_instance}.Hw Management Service Get Loggable Entities  ${device_uuid}
    ${state}=  Get From Dictionary  ${response}  status
    Run Keyword If   ${with_check} == ${True}  Should Be Equal  ${state}  OK_STATUS
    ${response_uuid}=  Get From Dictionary  ${response}  device_uuid
    Run Keyword If   ${with_check} == ${True}  Should Be Equal  ${uuid}  ${response_uuid}
    ${is_loglevels_in}=  Run Keyword And Return Status  Dictionary Should Contain Key  ${response}  logLevels
    ${loggable_entities}=  Run Keyword If  ${is_loglevels_in}==${True}  Get From Dictionary  ${response}  logLevels
    ...  ELSE  Create Dictionary
    Log  ${loggable_entities}
    [Return]  ${loggable_entities}

Get X Loggable Entities
    [Documentation]  get x (at least!) loggable entities and their loglevel of a device back to the user
    [Arguments]  ${lib_instance}  ${uuid}  ${number_entities}  ${with_check}=${TRUE}
    ${loggable_entities}=  Loggable Entities  dmi1  ${suite_device_uuid}  ${with_check}
    ${entities}=  Create Dictionary
    ${counter}=  Set Variable  ${1}
    FOR  ${entry}  IN  @{loggable_entities}
        log  ${entry}
        ${loggable_app}=  Get From Dictionary   ${entry}  entities
        ${loggable_app}=  Get From List  ${loggable_app}  0
        ${log_level}=  Get From Dictionary   ${entry}  logLevel
        Set To Dictionary  ${entities}  ${loggable_app}  ${log_level}
        Exit For Loop If    ${number_entities}==${counter}
        ${counter}=  Set Variable  ${counter+1}
    END
    ${size}=  GetLength  ${entities}
    [Return]  ${entities}

Set Component Inventory Info Unimplemented
    [Documentation]    This keyword sets a new value
    [Arguments]    ${uuid}    ${component_uuid}    ${component_name}    ${new_value}
    # try to set a component (note: currently not supported!)
    ${modifiableComp}=   Evaluate    {'name':'${new_value}'} 
    ${HWCompSetReq}=    Create Dictionary    device_uuid=${uuid}    component_uuid=${component_uuid}
    Set To Dictionary    ${HWCompSetReq}    component_name=${component_name}    changes=${modifiableComp}
    ${state}    ${response}   Run Keyword And Ignore Error    
    ...    dmi1.Hw Management Service Set Hw Component Info    ${HWCompSetReq}
    Should Contain   ${response}      StatusCode.UNIMPLEMENTED
