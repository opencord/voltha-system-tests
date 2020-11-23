*** Settings ***
Library           Process
Library           robot_grpc.Dmi    WITH NAME    dmi1
Library           robot_grpc.Collections    WITH NAME    tools
Library           robot_kafka.KafkaClient    WITH NAME    kafka
Library           Collections
Library           BuiltIn
Library           ../../libraries/utility.py    WITH NAME    utility
Resource          ../../libraries/dmi-basics.robot
Variables         ../../variables/variables.py
Variables         dmi-components.yaml
Suite Setup       Suite Setup
Suite Teardown    Suite Teardown

*** Variables ***
${DEVICEMANAGER_IP}    ${GIVEN_DM_IP}
${DEVICEMANAGER_PORT}    ${GIVEN_DM_PORT}
${OLT_IP}         ${GIVEN_OLT_IP}

*** Test Cases ***
Start and Stop Managing Device In Device Manager
    [Documentation]     add/remove device in device manager (testcase is done by Suite Setup and Suite Teardown)
    # this tescase exist, to have the possiblity to check only the Start-/Stop-ManagingDevice
    # can be run via adding parameter ("-t add and remove device in device manager") to the robot call!
    No Operation

Get Inventory Data
    [Documentation]     get physical inventory data from OLT
    &{PhyInvReq}=    Evaluate    {'device_uuid':${suite_device_uuid}}
    ${inventory}=    dmi1.Hw Management Service Get Physical Inventory    ${PhyInvReq}
    ${result}=    Get From List    ${inventory}    0
    Should Be Equal     ${result}[status]    OK_STATUS
    # check inventory from device against the parameters in components.yaml!
    FOR     ${component}    IN  @{dm_components}
        ${is_contained}=    Run Keyword And Return Status   List Should Contain Value  ${component}     data_type
        ${result}=  Run Keyword If   ${is_contained}==${True}   Run Keyword
        ...   utility.check_Inventory_Element    @{inventory}    ${component['description']}    ${component['name']}   ${component['data_type']}
        ...   ELSE  Run Keyword     utility.check_Inventory_Element    @{inventory}    ${component['description']}    ${component['name']}
        Should be True    ${result}
    END

Get Configurable Component Inventory Info
    [Documentation]     get physical component info (cpu 0/1, pluggable-fan 0/1/1)
    &{PhyInvReq}=    Evaluate    {'device_uuid':${suite_device_uuid}}
    ${inventory}=    dmi1.Hw Management Service Get Physical Inventory    ${PhyInvReq}
    ${result}=    Get From List    ${inventory}    0
    Should Be Equal     ${result}[status]    OK_STATUS
    ${name_hw1}=    Convert To String    ${dm_hardware[0]['hw_1']}
    ${name_hw2}=    Convert To String    ${dm_hardware[0]['hw_2']}
    FOR    ${element}    IN    @{inventory}
        ${uuid_hw1}=    utility.get_uuid_from_Inventory_Element    ${element}    ${name_hw1}
        Should Not Be Equal     ${None}      ${uuid_hw1}
        ${uuid_hw2}=    utility.get_uuid_from_Inventory_Element    ${element}    ${name_hw2}
        Should Not Be Equal     ${None}     ${uuid_hw2}
    END
    ${hwComInfoReq}=    Evaluate    {'device_uuid':${suite_device_uuid}, 'component_uuid':${uuid_hw1}, 'component_name':'${name_hw1}'}
    ${hwComInfoRes}=     dmi1.Hw Management Service Get Hw Component Info    ${hwComInfoReq}
    # check values of hw_1
    ${hwComInfoRes}=    Get From List    ${hwComInfoRes}   0
    ${status}=     Get From Dictionary  ${hwComInfoRes}     status
    Should Be Equal    ${status}    OK_STATUS
    ${component}=    Get From Dictionary    ${hwComInfoRes}   component
    ${value_name}=  Get From Dictionary     ${component}    name
    Should be Equal    ${value_name}      ${name_hw1}
    # check values of hw_2
    ${hwComInfoReq}=    Evaluate    {'device_uuid':${suite_device_uuid}, 'component_uuid':${uuid_hw2}, 'component_name':'${name_hw2}'}
    ${hwComInfoRes}=     dmi1.Hw Management Service Get Hw Component Info    ${hwComInfoReq}
    ${hwComInfoRes}=    Get From List    ${hwComInfoRes}   0
    ${status}=     Get From Dictionary  ${hwComInfoRes}     status
    Should Be Equal    ${status}    OK_STATUS
    ${component}=    Get From Dictionary    ${hwComInfoRes}   component
    ${value_name}=  Get From Dictionary     ${component}    name
    Should be Equal    ${value_name}      ${name_hw2}
    # try to set a component (note: not supported by device manager)
    ${HWCompSetReq}=    Evaluate    {'device_uuid':${suite_device_uuid}, 'component_uuid':${uuid_hw1}, 'component_name':'${name_hw1}', 'changes':${suite_device_name}}
    ${state}    ${response}   Run Keyword And Ignore Error    dmi1.Hw Management Service Set Hw Component Info    ${HWCompSetReq}
    Should Contain   ${response}      StatusCode.UNIMPLEMENTED

*** Keywords ***
Suite Setup 
    dmi1.Connection Open    ${DEVICEMANAGER_IP}    ${DEVICEMANAGER_PORT}
    ${suite_device_uuid}=    Start Managing Device  dmi1    ${OLT_IP}    BBSim-BBSIM_OLT_0
    ${suite_device_name}=    Evaluate    {'name':'BBSim-BBSIM_OLT_0'}
    Set Suite Variable     ${suite_device_uuid}
    Set Suite Variable     ${suite_device_name}

Suite Teardown
    Stop Managing Device   dmi1    BBSim-BBSIM_OLT_0
    dmi1.Connection Close
    Search For Managed Devices And Stop Managing It     dmi1
 