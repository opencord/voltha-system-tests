# Copyright 2020 ADTRAN, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

*** Settings ***
Documentation    Library test suite for the grpc_robot library. To run the test suite, the fake device manager from
...    _./servers/dmi_ must have been started beforehand with command _python3 dmi_server.py_.
Library    OperatingSystem    WITH NAME    os
Library    String
Library    Collections
Variables    ./variables.py

*** Test Cases ***
Library import
    [Documentation]    Checks if the grpc_robot libraries can be imported.
    Import Library    grpc_robot.Dmi    WITH NAME    dmi
    Import Library    grpc_robot.Collections
    Import Library    grpc_robot.DmiTools    WITH NAME    tools

library_versions
    [Documentation]    Checks if the library returns the installed library and device-management-interface versions.
    [Template]    version_check
    grpc-robot    dmi.Library Version Get
    device-management-interface    dmi.Dmi Version Get

keywords
    [Documentation]    Checks if the keyword name exists in the library's keyword list.
    Keyword Should Exist    dmi.connection_close
    Keyword Should Exist    dmi.connection_open
    Keyword Should Exist    dmi.connection_parameters_get
    Keyword Should Exist    dmi.connection_parameters_set
    Keyword Should Exist    dmi.hw_event_mgmt_service_list_events
    Keyword Should Exist    dmi.hw_event_mgmt_service_update_events_configuration
    Keyword Should Exist    dmi.hw_management_service_get_hw_component_info
    Keyword Should Exist    dmi.hw_management_service_get_logging_endpoint
    Keyword Should Exist    dmi.hw_management_service_get_managed_devices
    Keyword Should Exist    dmi.hw_management_service_get_msg_bus_endpoint
    Keyword Should Exist    dmi.hw_management_service_get_physical_inventory
    Keyword Should Exist    dmi.hw_management_service_set_hw_component_info
    Keyword Should Exist    dmi.hw_management_service_set_logging_endpoint
    Keyword Should Exist    dmi.hw_management_service_set_msg_bus_endpoint
    Keyword Should Exist    dmi.hw_management_service_start_managing_device
    Keyword Should Exist    dmi.hw_management_service_stop_managing_device
    Keyword Should Exist    dmi.hw_management_service_get_loggable_entities
    Keyword Should Exist    dmi.hw_management_service_set_log_level
    Keyword Should Exist    dmi.hw_management_service_get_log_level
    Keyword Should Exist    dmi.hw_metrics_mgmt_service_get_metric
    Keyword Should Exist    dmi.hw_metrics_mgmt_service_list_metrics
    Keyword Should Exist    dmi.hw_metrics_mgmt_service_update_metrics_configuration
    Keyword Should Exist    dmi.sw_management_service_activate_image
    Keyword Should Exist    dmi.sw_management_service_download_image
    Keyword Should Exist    dmi.sw_management_service_revert_to_standby_image
    Keyword Should Exist    dmi.sw_management_service_get_software_version
    Keyword Should Exist    tools.hw_metrics_mgmt_decode_metric

dmi
    [Documentation]    Checks the RPC keywords whether or not they handle their input and output correctly and uses the
    ...    fake device manager for that. The fake device manager returns _OK_STATUS_ for each RPC. The variables
    ...    _${keywords_to_skip}_ and _${params}_ are defined in the variables file _./variables.py_.
    [Setup]    dmi.Connection Open    host=127.0.0.1    port=50051
    ${keywords}    Run Keyword    dmi.Get Keyword Names
    FOR    ${keyword}    IN    @{keywords}
        Continue For Loop If    '${keyword}' in ${keywords_to_skip}
        ${status}    ${params}    Run Keyword And Ignore Error    Get From Dictionary     ${param_dicts}    ${keyword}
        Run Keyword If    '${status}' == 'FAIL'    Log    no parameters available for keyword '${keyword}'    WARN
        Continue For Loop If    '${status}' == 'FAIL'
        Run Keyword If    ${params} == ${NONE}    ${keyword}    ELSE    ${keyword}    ${params}
    END
    [Teardown]    dmi.Connection Close

connection_params
    [Documentation]    Checks the connection parameter settings.
    ${new_timeout}    Set Variable    100
    ${settings_before}    dmi.Connection Parameters Get
    ${settings_while_set}    dmi.Connection Parameters Set    timeout=${new_timeout}
    ${settings_after}    dmi.Connection Parameters Get
    Should Be Equal    ${settings_before}    ${settings_while_set}
    Should Be Equal As Integers     ${settings_after}[timeout]    ${new_timeout}

enum_and_default_values
    [Documentation]    Checks the optional parameters _return_enum_integer_ and _return_defaults_ of the RPC keywords to
    ...    control their output. Check keyword documentation for the meaning of the parameters.
    ...    *Note*: The fake device manager must be running for this test case.
    [Setup]    dmi.Connection Open    host=127.0.0.1    port=50051
    ${params}   Get From Dictionary    ${param_dicts}    hw_management_service_get_log_level
    ${return}   hw_management_service_get_log_level     ${params}
    Should Be Equal As Strings    ${return}[status]    OK_STATUS
    Dictionary Should Not Contain Key     ${return}    reason
    ${return}   hw_management_service_get_log_level     ${params}    return_enum_integer=true
    Should Be Equal As Integers    ${return}[status]    1
    Dictionary Should Not Contain Key     ${return}    reason
    ${return}   hw_management_service_get_log_level     ${params}    return_enum_integer=${TRUE}
    Should Be Equal As Integers    ${return}[status]    1
    Dictionary Should Not Contain Key     ${return}    reason
    ${return}   hw_management_service_get_log_level     ${params}    return_defaults=true
    Should Be Equal As Strings    ${return}[status]    OK_STATUS
    Should Be Equal As Strings    ${return}[reason]    UNDEFINED_REASON
    ${return}   hw_management_service_get_log_level     ${params}    return_defaults=${TRUE}
    Should Be Equal As Strings    ${return}[status]    OK_STATUS
    Should Be Equal As Strings    ${return}[reason]    UNDEFINED_REASON
    ${return}   hw_management_service_get_log_level     ${params}    return_enum_integer=true    return_defaults=true
    Should Be Equal As Integers    ${return}[status]    1
    Should Be Equal As Integers    ${return}[reason]    0
    [Teardown]    dmi.Connection Close

tools
    [Documentation]    Checks some functions from the tools library which shall support the tester with general functionality.
    ${dict_1}    Create Dictionary    name=abc    type=123
    ${dict_2}    Create Dictionary    name=def    type=456
    ${list}    Create List    ${dict_1}    ${dict_2}
    ${return_dict}    grpc_robot.Collections.List Get Dict By Value    ${list}    name    def
    Should Be Equal    ${return_dict}[type]    456

*** Keywords ***
version_check
    [Documentation]    Determines the version of the installed package and compares it with the returned version of the
    ...    corresponding keyword.
    [Arguments]    ${package_name}     ${kw_name}
    ${pip show}    os.Run    python3 -m pip show ${package_name} | grep Version
    ${pip show}    Split To Lines    ${pip show}
    FOR    ${line}    IN    @{pip show}
         ${is_version}    Evaluate    '${line}'.startswith('Version')
         Continue For Loop If    not ${is_version}
         ${pip_version}    Evaluate    '${line}'.split(':')[-1].strip()
    END
    ${lib_version}    Run Keyword    ${kw_name}
    Should Be Equal    ${pip_version}    ${lib_version}
