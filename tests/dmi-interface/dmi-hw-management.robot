# Copyright 2020-present Open Networking Foundation
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
${OLT_NAME}    ${GIVEN_OLT_NAME}

${has_dataplane}    True

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
    Check Dmi Status  ${inventory}[0]  OK_STATUS
    FOR  ${component}  IN  @{dm_components}
        Log  ${component}
        Check Physical Inventory  ${inventory}  ${component}
    END

Get Set Configurable Component Inventory Info
    [Documentation]  get physical component info of all hw in given yaml file
    [Tags]  functionalDMI  GetSetConfigurableComponentInventoryInfoDMI
    &{PhyInvReq}=  Evaluate    {'device_uuid':${suite_device_uuid}}
    ${inventory}=  dmi1.Hw Management Service Get Physical Inventory    ${PhyInvReq}
    Check Dmi Status  ${inventory}[0]  OK_STATUS
    FOR  ${component}  IN  @{dm_components}
        Log  ${component}
        ${component_name}=  Convert To String  ${component['name']}
        ${component_uuid}=  Get Component Uuid From Inventory  ${inventory}  ${component_name}
        ${hwComInfoReq}=    Create Dictionary    device_uuid=${suite_device_uuid}    component_uuid=${component_uuid}
        Set To Dictionary    ${hwComInfoReq}    component_name=${component_name}
        ${hwComInfoRes}=  dmi1.Hw Management Service Get Hw Component Info  ${hwComInfoReq}
        ${hwComInfoRes}=  Get From List  ${hwComInfoRes}  0
        Check Dmi Status  ${hwComInfoRes}  OK_STATUS
        ${res_component}=  Get From Dictionary  ${hwComInfoRes}  component
        ${value_name}=  Get From Dictionary  ${res_component}  name
        Should be Equal  ${value_name}  ${component_name}
        # Try setting 'name' field
        # (for BBSim the set api is not implemented)
        # (for Physical Pod 'modifying component names is not supported')
        ${set_name_status}=    Set Variable If    ${has_dataplane}    ERROR_STATUS    UNIMPLEMENTED
        Set Component Inventory Info
        ...    ${suite_device_uuid}    ${component_uuid}    ${component_name}    name    new-value    ${set_name_status}
        # Try setting 'alias' (any, other than name) field (for BBSim the set api is not implemented)
        ${set_alias_status}=    Set Variable If    ${has_dataplane}    OK_STATUS    UNIMPLEMENTED
        Set Component Inventory Info
        ...    ${suite_device_uuid}    ${component_uuid}    ${component_name}    alias    ${component_name}    ${set_alias_status}
        # Reset alias field
        Set Component Inventory Info
        ...    ${suite_device_uuid}    ${component_uuid}    ${component_name}    alias    ${None}    ${set_alias_status}
    END

Get Loggable Entities
    [Documentation]  get the loggable entities of the device
    [Tags]  functionalDMI  GetLoggableEntitiesDMI  bbsimUnimplementedDMI
    ${loggable_entities}=  Loggable Entities  dmi1  ${suite_device_uuid}
    ${size_loggable_entities}=  Get Length  ${loggable_entities}
    Should Be True  ${size_loggable_entities} > 5

Set Get Logging Endpoint
    [Documentation]  set/get the loggable endpoint of a device
    [Tags]  functionalDMI  SetGetLoggingEndpointDMI  bbsimUnimplementedDMI
    ${defined_endpoint}=  Set Variable  127.0.0.1
    ${defined_protocol}=  Set Variable  udp
    Set Log Endpoint  dmi1  ${suite_device_uuid}  ${defined_endpoint}  ${defined_protocol}
    # now the new logging endpoint and protocol should be set!
    ${uuid}=  Evaluate  {'uuid':${suite_device_uuid}}
    ${log_endpoint}=   dmi1.Hw Management Service Get Logging Endpoint  ${uuid}
    Check Dmi Status  ${log_endpoint}  OK_STATUS
    ${get_endpoint}=  Get From Dictionary  ${log_endpoint}  logging_endpoint
    ${get_protocol}=  Get From Dictionary  ${log_endpoint}  logging_protocol
    Should Be Equal  ${get_endpoint}  ${defined_endpoint}
    Should Be Equal  ${get_protocol}  ${defined_protocol}
    # remove logging endpoint
    ${defined_endpoint}=  Set Variable
    ${defined_protocol}=  Set Variable
    Set Log Endpoint  dmi1  ${suite_device_uuid}  ${defined_endpoint}  ${defined_protocol}

Set Get LogLevel
    [Documentation]  set and get the log level of a device
    [Tags]  functionalDMI  SetGetLogLevelDMI  skipped  bbsimUnimplementedDMI
    ${loggable_entities}=  Get X Loggable Entities  dmi1  ${suite_device_uuid}  2
    ${size}=  GetLength  ${loggable_entities}
    Should Be True  ${size} >= 2
    # set new loglevel
    Set Logging Level  dmi1  ${suite_device_uuid}  ${loggable_entities}  ERROR
    # get the loglevel
    ${log_list}=  Create List
    ${entity}=  Set Variable  ${loggable_entities}[0][entities]
    FOR  ${log_entity}  IN  @{entity}
        Append To List  ${log_list}  ${log_entity}
    END
    ${entity}=  Set Variable  ${loggable_entities}[1][entities]
    FOR  ${log_entity}  IN  @{entity}
        Append To List  ${log_list}  ${log_entity}
    END
    ${loglvl_request}=  Evaluate  {'device_uuid':${suite_device_uuid}, 'entities':${log_list}}
    ${response}=   dmi1.Hw Management Service Get Log Level  ${loglvl_request}
    Check Dmi Status  ${response}  OK_STATUS
    FOR  ${counter}  IN RANGE  0  2
        Should Be True  '${response}[logLevels][${counter}][logLevel]' == 'ERROR'
    END
    # set loglevel back to default
    Set Logging Level  dmi1  ${suite_device_uuid}  ${loggable_entities}  WARN

*** Keywords ***
Suite Setup
    [Documentation]  start a managed device in the device manager
    dmi1.Connection Open  ${DEVICEMANAGER_IP}  ${DEVICEMANAGER_PORT}
    ${suite_device_uuid}=  Start Managing Device  dmi1  ${OLT_IP}  ${OLT_NAME}
    ${suite_device_name}=  Evaluate    {'name':'${OLT_NAME}'}
    Set Suite Variable  ${suite_device_uuid}
    Set Suite Variable  ${suite_device_name}

Suite Teardown
    [Documentation]   stop a managed device in device manager
    Stop Managing Device    dmi1    ${OLT_NAME}
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
        ${result}=  utility.check_Inventory_Element  ${inventory_element}  ${component['name']}
        ...    ${component_element['element']}  ${component_element['value']}
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
    [Return]  ${loggable_entities}

Get X Loggable Entities
    [Documentation]  get x (at least!) loggable entities and their loglevel of a device back to the user
    [Arguments]  ${lib_instance}  ${uuid}  ${number_entities}=5000  ${with_check}=${TRUE}
    ${loggable_entities}=  Loggable Entities  ${lib_instance}  ${suite_device_uuid}  ${with_check}
    ${entities2}=  Create Dictionary
    ${entities}=  Create List
    ${counter}=  Set Variable  ${1}
    FOR  ${entry}  IN  @{loggable_entities}
        Append To List  ${entities}  ${entry}
        Exit For Loop If    ${number_entities}==${counter}
        ${counter}=  Set Variable  ${counter+1}
    END
    [Return]  ${entities}

Set Component Inventory Info
    [Documentation]    This keyword sets a new value
    [Arguments]    ${uuid}    ${component_uuid}    ${component_name}    ${component_field}    ${new_value}    ${status_code}
    ${modifiableComp}=   Evaluate    {'${component_field}':'${new_value}'}
    ${HWCompSetReq}=    Create Dictionary    device_uuid=${uuid}    component_uuid=${component_uuid}
    Set To Dictionary    ${HWCompSetReq}    component_name=${component_name}    changes=${modifiableComp}
    ${state}    ${response}   Run Keyword And Ignore Error
    ...    dmi1.Hw Management Service Set Hw Component Info    ${HWCompSetReq}
    Log    ${response}
    Run Keyword If    '${state}'=='FAIL'    Should Contain    ${response}    StatusCode.${status_code}
    ...    ELSE    Check Dmi Status    ${response}    ${status_code}

Set Logging Level
    [Documentation]  set the given loglevel in device
    [Arguments]  ${lib_instance}  ${uuid}  ${loggable_entities}  ${log_level}
    FOR  ${counter}  IN RANGE  0  2
        ${loggable_entity}  Get From List  ${loggable_entities}  ${counter}
        Set To Dictionary  ${loggable_entity}  logLevel  ${log_level}
    END
    ${loglvl_request}=  Evaluate  {'device_uuid':${uuid}, 'loglevels':${loggable_entities}}
    ${response}=   Run Keyword  ${lib_instance}.Hw Management Service Set Log Level  ${loglvl_request}
    Check Dmi Status  ${response}  OK_STATUS

Set Log Endpoint
    [Documentation]  set the given logging endpoint in device
    [Arguments]  ${lib_instance}  ${uuid}  ${defined_endpoint}  ${defined_protocol}
    ${set_endpoint}=    Create Dictionary    device_uuid=${suite_device_uuid}    logging_endpoint=${defined_endpoint}
    Set To Dictionary    ${set_endpoint}    logging_protocol=${defined_protocol}
    ${response}=  Run Keyword  ${lib_instance}.Hw Management Service Set Logging Endpoint  ${set_endpoint}
    Check Dmi Status  ${response}  OK_STATUS
