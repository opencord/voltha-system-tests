*** Settings ***
Library    OperatingSystem    WITH NAME    os
Library    String
Library    Collections
Library    grpc_robot.Dmi    WITH NAME    dmi
Library    grpc_robot.Collections
Variables  ./variables.py

*** Test Cases ***
library_versions
    [Template]    version_check
    grpc-robot    dmi.Library Version Get
    device-management-interface    dmi.Dmi Version Get

keywords
    [Template]    keyword_exist
    dmi    connection_close
    dmi    connection_open
    dmi    connection_parameters_get
    dmi    connection_parameters_set
    dmi    hw_event_mgmt_service_list_events
    dmi    hw_event_mgmt_service_update_events_configuration
    dmi    hw_management_service_get_hw_component_info
    dmi    hw_management_service_get_logging_endpoint
    dmi    hw_management_service_get_managed_devices
    dmi    hw_management_service_get_msg_bus_endpoint
    dmi    hw_management_service_get_physical_inventory
    dmi    hw_management_service_set_hw_component_info
    dmi    hw_management_service_set_logging_endpoint
    dmi    hw_management_service_set_msg_bus_endpoint
    dmi    hw_management_service_start_managing_device
    dmi    hw_management_service_stop_managing_device
    dmi    hw_management_service_get_loggable_entities
    dmi    hw_management_service_set_log_level
    dmi    hw_management_service_get_log_level
    dmi    hw_metrics_mgmt_service_get_metric
    dmi    hw_metrics_mgmt_service_list_metrics
    dmi    hw_metrics_mgmt_service_update_metrics_configuration
    dmi    sw_management_service_activate_image
    dmi    sw_management_service_download_image
    dmi    sw_management_service_revert_to_standby_image
    dmi    sw_management_service_get_software_version

dmi
    [Setup]    dmi.Connection Open    host=127.0.0.1    port=50051
    ${keywords}    Run Keyword    dmi.Get Keyword Names
    FOR    ${keyword}    IN    @{keywords}
        ${skip_keyword}    Evaluate    '${keyword}' in ['connection_open', 'connection_close', 'connection_parameters_get', 'connection_parameters_set', 'get_keyword_names', 'library_version_get', 'dmi_version_get']
        Continue For Loop If    ${skip_keyword}
        ${status}    ${params}    Run Keyword And Ignore Error    Get From Dictionary     ${param_dicts}    ${keyword}
        Run Keyword If    '${status}' == 'FAIL'    Log    no parameters available for keyword '${keyword}'    WARN
        Continue For Loop If    '${status}' == 'FAIL'
        Run Keyword If    ${params} == ${NONE}    ${keyword}    ELSE    ${keyword}    ${params}
    END
    [Teardown]    dmi.Connection Close

connection_params
    ${new_timeout}    Set Variable    100
    ${settings_before}    dmi.Connection Parameters Get
    ${settings_while_set}    dmi.Connection Parameters Set    timeout=${new_timeout}
    ${settings_after}    dmi.Connection Parameters Get
    Should Be Equal    ${settings_before}    ${settings_while_set}
    Should Be Equal As Integers     ${settings_after}[timeout]    ${new_timeout}

enum_and_default_values
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
    ${dict_1}    Create Dictionary    name=abc    type=123
    ${dict_2}    Create Dictionary    name=def    type=456
    ${list}    Create List    ${dict_1}    ${dict_2}
    ${return_dict}    list_get_dict_by_value    ${list}    name    def
    Should Be Equal    ${return_dict}[type]    456

*** Keywords ***
version_check
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

keyword_exist
    [Arguments]    ${library_name}    ${keyword_name}
    ${keywords}    Run Keyword    ${library_name}.Get Keyword Names
    Should Contain    ${keywords}    ${keyword_name}


