# Copyright 2021 - present Open Networking Foundation
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
Documentation     Library for various pm data (metrics) test utilities
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Library           CORDRobot
Library           ImportResource    resources=CORDRobot
Library           utility.py    WITH NAME    utility
Resource          ./voltctl.robot

*** Variables ***
# operators for value validations, needed for a better reading only
${gt}      >      # greater than
${ge}      >=     # greater equal
${lt}      <      # less than
${le}      <=     # less equal
${eq}      ==     # equal
${ne}      !=     # not equal

*** Keywords ***
#################################################################
# pre test keywords
#################################################################
Create Metric Dictionary
    [Documentation]    Create metric dict of metrics to test/validate
    ...                Created dictionary has to be set to suite variable!!!
    ${metric_dict}=     Create Dictionary
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # read available metric groups
        ${group_list}    ${interval_dict}=    Read Group List   ${onu_device_id}
        # read available groupmetrics
        ${groupmetrics_dict}=    Get Available Groupmetrics per Device    ${group_list}    ${onu_device_id}
        ${device_dict}=    Create Dictionary    MetricData    ${groupmetrics_dict}    GroupList    ${group_list}
        Set To Dictionary    ${metric_dict}    ${onu_device_id}    ${device_dict}
        Prepare Interval and Validation Data    ${metric_dict}    ${onu_device_id}    ${interval_dict}
    END
    log    ${metric_dict}
    [return]    ${metric_dict}

Get Available Groupmetrics per Device
    [Documentation]    Delivers avaiable groupmetrics incl. validation data of onu
    [Arguments]    ${group_list}    ${onu_device_id}
    ${groupmetric_dict}    Create Dictionary
    FOR    ${Item}    IN    @{group_list}
        ${item_dict}=    Read Group Metric Dict   ${onu_device_id}    ${Item}
        ${item_dict}=    Set Validation Operation    ${item_dict}    ${Item}
        ${item_dict}=    Set User Validation Operation    ${item_dict}    ${Item}
        ${item_dict}=    Set User Precondition Operation for Availability    ${item_dict}    ${Item}
        ${metric}=       Create Dictionary    GroupMetrics=${item_dict}
        ${dict}=       Create Dictionary    ${Item}=${metric}
        Set To Dictionary    ${groupmetric_dict}    ${Item}=${metric}
    END
    [return]    ${groupmetric_dict}

Set Validation Operation
    [Documentation]    Sets the validation operation per metric parameter
    [Arguments]    ${item_dict}    ${group}
    FOR    ${item}    IN    @{item_dict.keys()}
        ${type}=    Get From Dictionary    ${item_dict["${item}"]}    type
        ${item_dict}=     Run Keyword If
        ...               '${type}'=='COUNTER'    Set Validation Operation For Counter    ${item_dict}    ${item}    ${group}
        ...    ELSE IF    '${type}'=='CONTEXT'    Set Validation Operation For Context    ${item_dict}    ${item}    ${group}
        ...    ELSE IF    '${type}'=='GAUGE'      Set Validation Operation For Gauge      ${item_dict}    ${item}    ${group}
        ...    ELSE       Run Keyword And Continue On Failure    FAIL    Type (${type}) is unknown!
    END
    [return]    ${item_dict}

Set Validation Operation For Counter
    [Documentation]    Sets the validation operation for a counter
    [Arguments]    ${item_dict}    ${metric}    ${group}
    # will be overwritten by user operation and value if available
    ${first}=    Create Dictionary    operator=${ge}    operand=0
    # for real POD it must be >= previous counter value, in case of BBSim usage we got random values, so check >= 0
    ${successor}=     Run Keyword If    ${has_dataplane}    Create Dictionary    operator=${ge}    operand=previous
    ...    ELSE    Create Dictionary    operator=${ge}    operand=0
    ${ValidationOperation}=    Create Dictionary    first=${first}    successor=${successor}
    Set To Dictionary    ${item_dict['${metric}']}  ValidationOperation=${ValidationOperation}
    [return]    ${item_dict}

Set Validation Operation For Context
    [Documentation]    Sets the validation operation for a context
    [Arguments]    ${item_dict}    ${metric}    ${group}
    # will be overwritten by user operation and value if available
    ${first}=    Create Dictionary    operator=${ge}    operand=0
    ${successor}=     Create Dictionary    operator=${eq}    operand=previous
    ${ValidationOperation}=    Create Dictionary    first=${first}    successor=${successor}
    Set To Dictionary    ${item_dict['${metric}']}  ValidationOperation=${ValidationOperation}
    [return]    ${item_dict}

Set Validation Operation For Gauge
    [Documentation]    Sets the validation operation for a gauge
    [Arguments]    ${item_dict}    ${metric}    ${group}
    # will be overwritten by user operation and value if available
    ${first}=    Create Dictionary    operator=${ge}    operand=0
    ${successor}=     Create Dictionary    operator=${ge}    operand=0
    ${ValidationOperation}=    Create Dictionary    first=${first}    successor=${successor}
    Set To Dictionary    ${item_dict['${metric}']}  ValidationOperation=${ValidationOperation}
    [return]    ${item_dict}

Set User Validation Operation
    [Documentation]    Sets the user validation operation and value per metric parameter if available
    [Arguments]    ${item_dict}    ${group}
    ${variables}=  Get variables    no_decoration=Yes
    Return From Keyword If    not "pm_user_validation_data" in $variables      ${item_dict}
    Return From Keyword If    not '${group}' in ${pm_user_validation_data}      ${item_dict}
    FOR    ${item}    IN    @{item_dict.keys()}
        Continue For Loop If    not '${item}' in ${pm_user_validation_data['${group}']}
        ${operator}=    Get From Dictionary    ${pm_user_validation_data['${group}']['${item}']}    firstoperator
        ${operand}=     Get From Dictionary    ${pm_user_validation_data['${group}']['${item}']}    firstvalue
        ${first}=    Create Dictionary    operator=${operator}    operand=${operand}
        ${operator}=    Get From Dictionary    ${pm_user_validation_data['${group}']['${item}']}    successoroperator
        ${operand}=     Get From Dictionary    ${pm_user_validation_data['${group}']['${item}']}    successorvalue
        ${successor}=    Create Dictionary    operator=${operator}    operand=${operand}
        ${ValidationOperation}=    Create Dictionary    first=${first}    successor=${successor}
        Set To Dictionary    ${item_dict['${item}']}  ValidationOperation=${ValidationOperation}
    END
    [return]    ${item_dict}

Set User Precondition Operation for Availability
    [Documentation]    Sets the user precondition operation, value and element per metric parameter if available
    [Arguments]    ${item_dict}    ${group}
    ${variables}=  Get variables    no_decoration=Yes
    Return From Keyword If    not "pm_user_precondition_data" in $variables      ${item_dict}
    Return From Keyword If    not '${group}' in ${pm_user_precondition_data}      ${item_dict}
    FOR    ${item}    IN    @{item_dict.keys()}
        Continue For Loop If    not '${item}' in ${pm_user_precondition_data['${group}']}
        ${operator}=    Get From Dictionary    ${pm_user_precondition_data['${group}']['${item}']}    operator
        ${operand}=     Get From Dictionary    ${pm_user_precondition_data['${group}']['${item}']}    value
        ${element}=     Get From Dictionary    ${pm_user_precondition_data['${group}']['${item}']}    precondelement
        ${precond}=     Create Dictionary    operator=${operator}    operand=${operand}    element=${element}
        Set To Dictionary    ${item_dict['${item}']}  Precondition=${precond}
    END
    [return]    ${item_dict}

Prepare Interval and Validation Data
    [Documentation]    Prepares interval and validation data of onu
    [Arguments]    ${METRIC_DICT}    ${onu_device_id}    ${interval_dict}
    ${list}=    Get From Dictionary     ${METRIC_DICT['${onu_device_id}']}    GroupList
    FOR    ${Item}    IN    @{list}
        ${metric}=    Get From Dictionary     ${METRIC_DICT['${onu_device_id}']['MetricData']}    ${Item}
        Set To Dictionary    ${metric}    NumberOfChecks=0
        ${default_interval}=    Get From Dictionary    ${interval_dict}    ${Item}
        # convert interval in seconds and remove unit
        ${default_interval}=    Validate Time Unit    ${default_interval}    False
        ${intervals}    Create Dictionary    default=${default_interval}    user=-1    current=${default_interval}
        Set To Dictionary    ${metric}    Intervals=${intervals}
        Set To Dictionary    ${METRIC_DICT['${onu_device_id}']['MetricData']}    ${Item}=${metric}
    END

Prepare Group Interval List per Device Id
    [Documentation]    Prepares group-interval list per device id
    [Arguments]    ${dev_id}   ${user}=False    ${group}=${EMPTY}
    ${list}=    Get From Dictionary    ${METRIC_DICT['${dev_id}']}    GroupList
    ${group_interval_list}   Create List
    FOR    ${Item}    IN    @{list}
        ${val}=    Run Keyword If    ${user}
        ...                Get From Dictionary    ${METRIC_DICT['${dev_id}']['MetricData']['${Item}']['Intervals']}    user
        ...        ELSE    Get From Dictionary    ${METRIC_DICT['${dev_id}']['MetricData']['${Item}']['Intervals']}    default
        ${dict}=     Create Dictionary    group=${Item}    interval=${val}
        Run Keyword If    '${group}'=='${EMPTY}' or '${group}'=='${Item}'   Append To List    ${group_interval_list}    ${dict}
    END
    [return]   ${group_interval_list}

Get Longest Interval per Onu
    [Documentation]    Delivers longest group interval per device id
    [Arguments]    ${dev_id}   ${user}=False
    ${list}=    Get From Dictionary    ${METRIC_DICT['${dev_id}']}    GroupList
    ${longest_interval}=    Set Variable    0
    FOR    ${Item}    IN    @{list}
        ${val}=    Run Keyword If    ${user}
        ...                Get From Dictionary    ${METRIC_DICT['${dev_id}']['MetricData']['${Item}']['Intervals']}    user
        ...        ELSE    Get From Dictionary    ${METRIC_DICT['${dev_id}']['MetricData']['${Item}']['Intervals']}    default
        ${longest_interval}=    Set Variable If    ${val} > ${longest_interval}    ${val}    ${longest_interval}
    END
    [return]   ${longest_interval}

Get Longest Interval
    [Documentation]    Delivers longest interval over all devices
    [Arguments]    ${user}=False
    ${longest_interval}=    Set Variable    0
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${onu_longest_interval}=    Run Keyword If     '${onu_device_id}'!='${EMPTY}'
        ...    Get Longest Interval per Onu    ${onu_device_id}    ${user}
        ${longest_interval}=    Set Variable If    ${onu_longest_interval} > ${longest_interval}    ${onu_longest_interval}
        ...    ${longest_interval}
    END
    [return]    ${longest_interval}

Determine Collection Interval
    [Documentation]    Delivers collection interval over all devices
    [Arguments]    ${user}=False
    ${longest_interval}=    Get Longest Interval    user=${user}
    ${collect_interval}=    evaluate    ((${longest_interval}*2)+(${longest_interval}*0.2))
    ${collect_interval}=    Validate Time Unit    ${collect_interval}
    [return]    ${collect_interval}

Set Group Interval per Onu
    [Documentation]    Sets group user interval in METRIC_DICT per device id
    [Arguments]    ${device_id}     ${group}    ${val}
    # convert interval in seconds and remove unit
    ${val}=    Validate Time Unit    ${val}    False
    Run Keyword If    '${group}' in ${METRIC_DICT['${device_id}']['MetricData']}
    ...    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']['Intervals']}    user=${val}

Set Group Interval All Onu
    [Documentation]    Sets group user interval in METRIC_DICT
    [Arguments]    ${group}    ${val}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${device_id}=    Get Device ID From SN    ${src['onu']}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        Set Group Interval per Onu    ${device_id}    ${group}    ${val}
    END

Activate And Validate Interval All Onu
    [Documentation]    Activates and validates group user interval taken from METRIC_DICT
    [Arguments]    ${user}=False    ${group}=${EMPTY}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${device_id}=    Get Device ID From SN    ${src['onu']}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        ${list}=    Prepare Group Interval List per Device Id    ${device_id}    ${user}    ${group}
        Activate And Validate Metrics Interval per Onu    ${device_id}    ${list}
    END

Activate And Validate Metrics Interval per Onu
    [Documentation]    Activates and validates interval of pm data per onu
    [Arguments]    ${device_id}    ${group_list}
    FOR    ${Item}    IN    @{group_list}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        ${group}=    Get From Dictionary     ${Item}    group
        ${val}=      Get From Dictionary     ${Item}    interval
        Continue For Loop If    not '${group}' in ${METRIC_DICT['${device_id}']['MetricData']}
        Continue For Loop If    '${val}'=='-1'
        # set the unit to sec
        ${val_with_unit}=    Validate Time Unit    ${val}
        Set and Validate Group Interval      ${device_id}    ${val_with_unit}    ${group}
        # update current interval in METRICS_DICT
        Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']['Intervals']}    current=${val}
    END

Set Validation Operation per Onu
    [Documentation]    Sets group validation data in METRIC_DICT per device id for passed metric element
    [Arguments]    ${device_id}     ${group}    ${metric_element}    ${validation_dict}
    Run Keyword If    '${group}' in ${METRIC_DICT['${device_id}']['MetricData']}
    ...    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']['GroupMetrics']['${metric_element}']}
    ...    ValidationOperation=${validation_dict}

Set Validation Operation All Onu
    [Documentation]    Sets group validation data in METRIC_DICT all devices and passed metric element
    [Arguments]    ${group}    ${metric_element}    ${validation_dict}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${device_id}=    Get Device ID From SN    ${src['onu']}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        Set Validation Operation per Onu    ${device_id}    ${group}    ${metric_element}    ${validation_dict}
    END

Set Validation Operation Passed Onu
    [Documentation]    Sets group validation data in METRIC_DICT for passed devices and passed metric element
    ...                Passed dictionary has to be format <device_id>:<Validation Dictionary>
    ...                Keyword 'Get Validation Operation All Onu' delivers such a dictionary.
    [Arguments]    ${group}    ${metric_element}    ${validation_dict_with_device_id}
    FOR    ${item}    IN    @{validation_dict_with_device_id.keys()}
        Continue For Loop If    not '${item}' in ${METRIC_DICT}
        ${validation_dict}=    Get From Dictionary    ${validation_dict_with_device_id}    ${item}
        Set Validation Operation per Onu    ${item}    ${group}    ${metric_element}    ${validation_dict}
    END

Get Validation Operation per Onu
    [Documentation]    Delivers group validation data in METRIC_DICT per device id for passed metric element
    [Arguments]    ${device_id}     ${group}    ${metric_element}
    ${validation_dict}=    Run Keyword If    '${group}' in ${METRIC_DICT['${device_id}']['MetricData']}
    ...    Get From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']['GroupMetrics']['${metric_element}']}
    ...    ValidationOperation
    [return]    ${validation_dict}

Get Validation Operation All Onu
    [Documentation]    Delivers group validation data in METRIC_DICT all devices for passed metric element
    [Arguments]    ${group}    ${metric_element}
    ${validation_dict_with_device}    Create Dictionary
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${device_id}=    Get Device ID From SN    ${src['onu']}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        ${validation_dict}=   Get Validation Operation per Onu    ${device_id}    ${group}    ${metric_element}
        Set To Dictionary    ${validation_dict_with_device}    ${device_id}=${validation_dict}
    END
    [return]    ${validation_dict_with_device}

#################################################################
# test keywords
#################################################################
Collect and Validate PM Data
    [Documentation]    Collecta PM-data from kafka and validates metrics
    [Arguments]    ${collect_interval}    ${clear}=True    ${user}=False    ${group}=${EMPTY}
    ${Kafka_Records}=    Get Metrics    ${collect_interval}    clear=${clear}
    ${RecordsLength}=    Get Length    ${Kafka_Records}
    FOR    ${Index}    IN RANGE    0    ${RecordsLength}
        ${metric}=    Set Variable    ${Kafka_Records[${Index}]}
        ${message}=    Get From Dictionary  ${metric}  message
        ${event}=    volthatools.Events Decode Event   ${message}    return_default=true
        Continue For Loop If    not 'kpi_event2' in ${event}
        ${slice}=    Get Slice Data From Event    ${event}
        Validate Slice Data   ${slice}    ${Kafka_Records}
        Set Previous Record    ${Index}    ${slice}
    END
    Validate Number of Checks    ${collect_interval}    user=${user}    group=${group}

Get Metrics
    [Documentation]    Delivers metrics from kafka
    [Arguments]    ${collect_interval}    ${clear}=True
    Run Keyword If    ${clear}    kafka.Records Clear
    Sleep    ${collect_interval}
    ${Kafka_Records}=    kafka.Records Get    voltha.events
    [return]    ${Kafka_Records}

Get Title From Metadata
    [Documentation]    Delivers the title of pm data from metadata
    [Arguments]    ${metadata}
    ${title}=    Get From Dictionary    ${metadata}      title
    [return]    ${title}

Get Device_Id From Metadata
    [Documentation]    Delivers the device-id of pm data from metadata
    [Arguments]    ${metadata}
    ${device_id}=    Get From Dictionary    ${metadata}      device_id
    [return]    ${device_id}

Get Timestamp From Metadata
    [Documentation]    Delivers the device-id of pm data from metadata
    [Arguments]    ${metadata}
    ${timestamp}=    Get From Dictionary    ${metadata}      ts
    [return]    ${timestamp}

Get Slice Data From Event
    [Documentation]    Delivers the slice data of pm data from event
    [Arguments]    ${event}
    ${kpi_event2}=    Get From Dictionary    ${event}         kpi_event2
    ${slice_data}=    Get From Dictionary    ${kpi_event2}    slice_data
    [return]    ${slice_data}

Validate Slice Data
    [Documentation]    Validates passed slice data
    [Arguments]    ${slice}    ${metric_records}
    ${result}=       Set Variable    True
    ${checked}=      Set Variable    False
    ${device_id}=    Set Variable    ${EMPTY}
    ${title}=        Set Variable    ${EMPTY}
    ${SliceLength}=    Get Length    ${slice}
    Validate Slice Metrics Integrity    ${slice}
    FOR    ${Index}    IN RANGE    0    ${SliceLength}
        ${metadata}=    Get From Dictionary    ${slice[${Index}]}    metadata
        ${metrics}=     Get From Dictionary    ${slice[${Index}]}    metrics
        ${title}=    Get Title From Metadata    ${metadata}
        ${device_id}=    Get Device_Id From Metadata    ${metadata}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        ${timestamp}=    Get Timestamp From Metadata    ${metadata}
        ${prevSliceIndex}=    Run Keyword If     'PreviousRecord' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']}
        ...    Get Previous Slice Index    ${device_id}    ${title}    ${metric_records}    ${metrics}
        ...    ELSE    Set Variable    0
        Continue For Loop If    ${prevSliceIndex}==-1
        Run Keyword If     'PreviousRecord' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']}
        ...    Validate Timestamp    ${device_id}    ${title}    ${timestamp}    ${metric_records}    ${prevSliceIndex}
        ${hasprev}=    Set Variable If     'PreviousRecord' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']}
        ...            True    False
        Validate Metrics Data   ${device_id}    ${title}    ${metrics}    ${hasprev}    ${metric_records}    ${prevSliceIndex}
        Validate Completeness of Metrics Data   ${device_id}    ${title}    ${metrics}
        ${checked}=    Set Variable    True
    END
    # increase number of checks, only once per slice
    Run Keyword If    ${checked}    Increase Number of Checks    ${device_id}    ${title}

Validate Slice Metrics Integrity
    [Documentation]    Valitdates the inegrity of the passed slice.
    ...                The pair 'entity_id' and 'class_id' has tor appear only once per slice!
    ...                In case of metric group UNI_Status parameter 'uni_port_no' appends to check!
    [Arguments]    ${slice}
    ${prev_values}    Create List
    ${SliceLength}=    Get Length    ${slice}
    FOR    ${Index}    IN RANGE    0    ${SliceLength}
        ${metadata}=    Get From Dictionary    ${slice[${Index}]}    metadata
        ${metrics}=     Get From Dictionary    ${slice[${Index}]}    metrics
        ${title}=    Get Title From Metadata    ${metadata}
        # get entity-id and class_id if available
        # class_id identifier differs in case of metric group UNI_Status, 'me_class_id' instead simple 'class_id'
        ${class_id_name}=   Run Keyword If    '${title}'=='UNI_Status'   Set Variable    me_class_id
        ...    ELSE    Set Variable    class_id
        Continue For Loop If    not 'entity_id' in ${metrics}
        Continue For Loop If    not '${class_id_name}' in ${metrics}
        ${entity_id}=    Get From Dictionary    ${metrics}    entity_id
        ${class_id}=     Get From Dictionary    ${metrics}    ${class_id_name}
        # additional handling for metric group UNI_Status, uni_port_no has to be matched too
        ${uni_port_no}=    Run Keyword If    '${title}'=='UNI_Status'    Get From Dictionary    ${metrics}    uni_port_no
        ...    ELSE    Set Variable    ${Index}
        ${current_values}=    Create Dictionary    entity_id=${entity_id}    class_id=${class_id}    uni_port_no=${uni_port_no}
        Run Keyword And Continue On Failure    Should Not Contain    ${prev_values}    ${current_values}
        Append To List    ${prev_values}    ${current_values}
    END

Get Previous Slice Index
    [Documentation]    Delivers the slice index of previous metrics.
    ...                Previous slice index will be identified by matching entity_ids.
    ...                In case of UNI_Status the me_class_id has to be matched too!
    [Arguments]    ${device_id}    ${title}    ${metric_records}    ${metrics}
    ${prevSliceIndex}=    Set Variable    0
    # get entity-id and class_id if available
    # class_id identifier differs in case of metric group UNI_Status, 'me_class_id' instead simple 'class_id'
    ${class_id_name}=   Run Keyword If    '${title}'=='UNI_Status'   Set Variable    me_class_id
    ...    ELSE    Set Variable    class_id
    Return From Keyword If    not 'entity_id' in ${metrics}    ${prevSliceIndex}
    Return From Keyword If    not '${class_id_name}' in ${metrics}    ${prevSliceIndex}
    ${entity_id}=    Get From Dictionary    ${metrics}    entity_id
    ${class_id}=     Get From Dictionary    ${metrics}    ${class_id_name}
    # get previous entity-id
    ${prev_index}=    Set Variable    ${METRIC_DICT['${device_id}']['MetricData']['${title}']['PreviousRecord']}
    ${pre_record}=    Set Variable    ${metric_records[${prev_index}]}
    ${message}=       Get From Dictionary  ${pre_record}  message
    ${event}=         volthatools.Events Decode Event   ${message}    return_default=true
    ${prev_slice}=    Get Slice Data From Event    ${event}
    ${prevSliceLength}=   Get Length    ${prev_slice}
    ${matched}=       Set Variable    False
    FOR    ${Index}    IN RANGE    0    ${prevSliceLength}
        ${prevmetrics}=    Get From Dictionary    ${prev_slice[${Index}]}    metrics
        ${prev_entity_id}=    Get From Dictionary    ${prevmetrics}    entity_id
        ${prev_class_id}=    Get From Dictionary    ${prevmetrics}    ${class_id_name}
        ${matched}=    Set Variable If   (${entity_id}==${prev_entity_id})and(${${class_id}}==${prev_class_id})   True   False
        ${prevSliceIndex}=    Set Variable If    ${matched}    ${Index}    -1
        Exit For Loop If    ${matched}
    END
    Run Keyword And Continue On Failure    Run Keyword Unless    ${matched}    FAIL
    ...    Could not find previous metrics for ${title} entity_id ${entity_id} of device ${device_id}!
    [return]    ${prevSliceIndex}

Validate Timestamp
    [Documentation]    Validates passed timestamp with timestamp of previous metrics
    [Arguments]    ${device_id}    ${title}    ${timestamp}    ${metric_records}    ${prevSliceIndex}
    # get previous timestamp
    ${prev_timestamp}=   Get Previous Timestamp    ${METRIC_DICT['${device_id}']['MetricData']['${title}']['PreviousRecord']}
    ...    ${metric_records}    ${prevSliceIndex}
    ${interval}=    Get From Dictionary  ${METRIC_DICT['${device_id}']['MetricData']['${title}']['Intervals']}
    ...    current
    ${interval}=    Convert To Integer    ${interval}
    ${check_value}=     Evaluate    abs(${prev_timestamp}+${interval}-${timestamp})
    Run Keyword And Continue On Failure    Run Keyword Unless    ${0} <= ${check_value} <= ${4}    FAIL
    ...    Wrong interval for ${title} of device ${device_id}!

Get Validation Operation
    [Documentation]    Delivers the stored validation operation of passed metrics
    [Arguments]    ${dev_id}    ${title}    ${item}    ${has_previous}
    ${w_wo_prev}=    Set Variable If    ${has_previous}    successor    first
    ${validation_operator}=    Get From Dictionary
    ...   ${METRIC_DICT['${dev_id}']['MetricData']['${title}']['GroupMetrics']['${item}']['ValidationOperation']['${w_wo_prev}']}
    ...   operator
    ${validation_operand}=    Get From Dictionary
    ...   ${METRIC_DICT['${dev_id}']['MetricData']['${title}']['GroupMetrics']['${item}']['ValidationOperation']['${w_wo_prev}']}
    ...   operand
    [return]    ${validation_operator}    ${validation_operand}

Get Previous Value
    [Documentation]    Delivers the previous value
    [Arguments]    ${device_id}    ${title}    ${item}    ${metric_records}    ${prevSliceIndex}
    ${prev_index}=    Set Variable    ${METRIC_DICT['${device_id}']['MetricData']['${title}']['PreviousRecord']}
    ${pre_record}=    Set Variable    ${metric_records[${prev_index}]}
    ${message}=       Get From Dictionary  ${pre_record}  message
    ${event}=         volthatools.Events Decode Event   ${message}    return_default=true
    ${slice}=         Get Slice Data From Event    ${event}
    ${metrics}=       Get From Dictionary    ${slice[${prevSliceIndex}]}    metrics
    ${prev_value}=    Get From Dictionary    ${metrics}    ${item}
    [return]    ${prev_value}

Validate Metrics Data
    [Documentation]    Validates passed metrics
    [Arguments]    ${device_id}    ${title}    ${metrics}    ${has_previous}    ${metric_records}    ${prevSliceIndex}
    FOR    ${item}    IN    @{metrics.keys()}
        ${operation}    ${validation_value}=    Get Validation Operation   ${device_id}    ${title}    ${item}    ${has_previous}
        # get previous value in case of ${has_previous}==True and ${validation_value}==previous
        ${validation_value}=    Run Keyword If    ${has_previous} and '${validation_value}'=='previous'   Get Previous Value
        ...    ${device_id}    ${title}    ${item}    ${metric_records}    ${prevSliceIndex}
        ...    ELSE    Set Variable    ${validation_value}
        ${current_value}=    Get From Dictionary    ${metrics}    ${item}
        ${result}=    utility.validate    ${current_value}    ${operation}    ${validation_value}
        ${msg}=    Catenate    Received value (${current_value}) from device (${device_id}) of group (${title}) for '${item}'
        ...    does not match!
        ...    Expected: <value> ${operation} ${validation_value}
        Run Keyword Unless    ${result}    Run Keyword And Continue On Failure    FAIL    ${msg}
    END

Validate Precondition for Availability
    [Documentation]    Validates passed metrics for stored precondition
    [Arguments]    ${device_id}    ${title}    ${metrics}     ${item}
    ${precond}=    Get From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']['GroupMetrics']['${item}']}
    ...    Precondition
    ${operation}=           Get From Dictionary    ${precond}    operator
    ${validation_value}=    Get From Dictionary    ${precond}    operand
    ${element}=             Get From Dictionary    ${precond}    element
    ${current_value}=       Get From Dictionary    ${metrics}    ${element}
    ${result}=    utility.validate    ${current_value}    ${operation}    ${validation_value}
    [return]    ${result}

Validate Completeness of Metrics Data
    [Documentation]    Validates passed metrics of completness
    [Arguments]    ${device_id}    ${title}    ${metrics}
    # get validation data
    ${validation_data}=    Set Variable    ${METRIC_DICT['${device_id}']['MetricData']['${title}']['GroupMetrics']}
    FOR    ${item}    IN    @{validation_data.keys()}
        ${precondfullfilled}=    Run Keyword If
        ...    'Precondition' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']['GroupMetrics']['${item}']}
        ...    Validate Precondition for Availability    ${device_id}    ${title}    ${metrics}     ${item}
        ...    ELSE    Set Variable    True
        Run Keyword If    (not '${item}' in ${metrics}) and ${precondfullfilled}    Run Keyword And Continue On Failure    FAIL
        ...    Missing metric (${item}) from device (${device_id}) of group (${title})
    END

Get Previous Timestamp
    [Documentation]    Deliveres the timestamp of the passed metrics record
    [Arguments]    ${prev_index}    ${metric_records}    ${prevSliceIndex}
    ${metric}=    Set Variable    ${metric_records[${prev_index}]}
    ${message}=    Get From Dictionary  ${metric}  message
    ${event}=    volthatools.Events Decode Event   ${message}    return_default=true
    ${slice}=    Get Slice Data From Event    ${event}
    ${metadata}=    Get From Dictionary    ${slice[${prevSliceIndex}]}    metadata
    ${timestamp}=    Get Timestamp From Metadata    ${metadata}
    [return]    ${timestamp}

Set Previous Record
    [Documentation]    Sets the previous record in METRIC_DICT for next validation
    [Arguments]    ${Index}    ${slice}
    # use first slice for further handling
    ${metadata}=    Get From Dictionary    ${slice[${0}]}    metadata
    ${title}=    Get Title From Metadata    ${metadata}
    ${device_id}=    Get Device_Id From Metadata    ${metadata}
    Return From Keyword If    not '${device_id}' in ${METRIC_DICT}
    ${metric}=    Get From Dictionary     ${METRIC_DICT['${device_id}']['MetricData']}    ${title}
    Set To Dictionary    ${metric}    PreviousRecord=${Index}
    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']}    ${title}=${metric}

Increase Number of Checks
    [Documentation]    Increases the NumberOfChecks value in METRIC_DICT for passed device id and title
    [Arguments]    ${device_id}    ${title}
    ${checks}=    Get From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    NumberOfChecks
    ${checks}=    evaluate    ${checks} + 1
    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    NumberOfChecks=${checks}

Validate Number of Checks
    [Documentation]    Validates the NumberOfChecks value in METRIC_DICT, must be at least >=2
    [Arguments]    ${collect_interval}    ${user}=False    ${group}=${EMPTY}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${device_id}=    Get Device ID From SN    ${src['onu']}
        ${list}=    Prepare Group Interval List per Device Id    ${device_id}    ${user}    ${group}
        Validate Number of Checks per Onu    ${device_id}    ${list}    ${collect_interval}
    END

Validate Number of Checks per Onu
    [Documentation]    Validates the NumberOfChecks value per ONU, must be at least >=2
    ...                Collecting of metrics will be calculated that at least each group has to be checked twice!
    ...                Correct value per group and its interval will be calculated!
    [Arguments]    ${device_id}    ${list}    ${collect_interval}
    FOR    ${Item}    IN    @{list}
        ${group}=    Get From Dictionary     ${Item}    group
        ${val}=      Get From Dictionary     ${Item}    interval
        # use interval value to skip groups, which should not be checked!
        Continue For Loop If    '${val}'=='-1'
        ${checks}=    Get From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']}    NumberOfChecks
        # remove time unit if available
        ${collect_interval}=    Validate Time Unit    ${collect_interval}    False
        ${expected_checks}=    evaluate    ${collect_interval}/${val}
        # remove float format (Validate Time Unit will this done:-))
        ${expected_checks}=    Validate Time Unit    ${expected_checks}    False
        Run Keyword And Continue On Failure    Run Keyword Unless    ${expected_checks} <= ${checks}    FAIL
        ...    Wrong number of pm-data (${checks}) for ${group} of device ${device_id}!
    END

#################################################################
# Post test keywords
#################################################################

Remove Previous Record
    [Documentation]    Removes the previous record in METRIC_DICT
    [Arguments]    ${device_id}    ${title}
    Remove From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    PreviousRecord

Reset Number Of Checks
    [Documentation]    Removes the previous record in METRIC_DICT
    [Arguments]    ${device_id}    ${title}
    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    NumberOfChecks=0

Clean Metric Dictionary per Onu
    [Documentation]    Cleans METRIC_DICT per onu device id
    [Arguments]    ${device_id}
    FOR    ${Item}    IN     @{METRIC_DICT['${device_id}']['GroupList']}
        Remove Previous Record    ${device_id}    ${Item}
        Reset Number Of Checks    ${device_id}    ${Item}
    END

Clean Metric Dictionary
    [Documentation]    Cleans METRIC_DICT
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Clean Metric Dictionary per Onu    ${onu_device_id}
    END
    log    ${METRIC_DICT}


#################################################################
# Helper keywords
#################################################################

Validate Time Unit
    [Documentation]    Converts the passed value in seconds and return it w/o unit
    ...                Conversion to string is needed to remove float format!
    [Arguments]    ${val}    ${unit}=True
    ${seconds}=    Convert Time    ${val}
    ${seconds}=    Convert To String    ${seconds}
    ${seconds}=    Get Substring    ${seconds}    0    -2
    ${seconds}=    Set Variable If    ${unit}    ${seconds}s    ${seconds}
    [return]    ${seconds}