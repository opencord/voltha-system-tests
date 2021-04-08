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
Documentation     Library for various pm data (metrics) utilities
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Library           CORDRobot
Library           ImportResource    resources=CORDRobot
Resource          ./voltctl.robot

*** Keywords ***
#################################################################
# pre test keywords
#################################################################
Create Metric Dictionary
    [Documentation]    create metric dict of metrics to test/validate
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
    [Documentation]    Delivers avaiable groupmetrics of onu
    [Arguments]    ${group_list}    ${onu_device_id}
    ${groupmetric_dict}    Create Dictionary
    FOR    ${Item}    IN    @{group_list}
        ${item_dict}    Read Group Metric Dict   ${onu_device_id}    ${Item}
        ${metric}=       Create Dictionary    GroupMetrics=${item_dict}
        ${dict}=       Create Dictionary    ${Item}=${metric}
        Set To Dictionary    ${groupmetric_dict}    ${Item}=${metric}
    END
    [return]    ${groupmetric_dict}

Prepare Interval and Validation Data
    [Documentation]    Prepares interval and validation data of onu
    [Arguments]    ${METRIC_DICT}    ${onu_device_id}    ${interval_dict}
    ${list}=    Get From Dictionary     ${METRIC_DICT['${onu_device_id}']}    GroupList
    FOR    ${Item}    IN    @{list}
        ${metric}=    Get From Dictionary     ${METRIC_DICT['${onu_device_id}']['MetricData']}    ${Item}
        Set To Dictionary    ${metric}    NumberOfChecks=0
        ${default_interval}=    Get From Dictionary    ${interval_dict}    ${Item}
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
    [Documentation]    Delivers longest interval
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

Set Group Interval per Onu
    [Documentation]    Sets group user interval in METRIC_DICT per device id
    [Arguments]    ${device_id}     ${group}    ${val}
    ${last}=    Get Substring    ${val}    -1
    ${isstring}=    Evaluate    isinstance($last, str)
    ${val}=    Run Keyword If    ${isstring}    Get Substring    ${val}    0    -1
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
    [Documentation]    Activates group user interval taken from METRIC_DICT
    [Arguments]    ${user}=False    ${group}=${EMPTY}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${device_id}=    Get Device ID From SN    ${src['onu']}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        ${list}=    Prepare Group Interval List per Device Id    ${device_id}    ${user}    ${group}
        Activate And Validate Metrics Interval per Onu    ${device_id}    ${list}
    END

Activate And Validate Metrics Interval per Onu
    [Documentation]    Sets and validates interval of pm data per onu
    [Arguments]    ${device_id}    ${group_list}
    FOR    ${Item}    IN    @{group_list}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        ${group}=    Get From Dictionary     ${Item}    group
        ${val}=      Get From Dictionary     ${Item}    interval
        Continue For Loop If    not '${group}' in ${METRIC_DICT['${device_id}']['MetricData']}
        Continue For Loop If    '${val}'=='-1'
        # set the unit to sec
        ${val_with_unit}=    Set Variable    ${val}s
        Set and Validate Group Interval      ${device_id}    ${val_with_unit}    ${group}
        # update current interval in METRICS_DICT
        Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']['Intervals']}    current=${val}
    END

#################################################################
# test keywords
#################################################################

Get Metrics
    [Documentation]    Get metrics from kafka
    [Arguments]    ${duration}    ${clear}=True
    Run Keyword If    ${clear}    kafka.Records Clear
    Sleep    ${duration}
    ${Kafka_Records}=    kafka.Records Get    voltha.events
    [return]    ${Kafka_Records}

Get Title From Metadata
    [Documentation]    delivers the title of pm data from metadata
    [Arguments]    ${metadata}
    ${title}=    Get From Dictionary    ${metadata}      title
    [return]    ${title}

Get Device_Id From Metadata
    [Documentation]    delivers the device-id of pm data from metadata
    [Arguments]    ${metadata}
    ${device_id}=    Get From Dictionary    ${metadata}      device_id
    [return]    ${device_id}

Get Timestamp From Metadata
    [Documentation]    delivers the device-id of pm data from metadata
    [Arguments]    ${metadata}
    ${timestamp}=    Get From Dictionary    ${metadata}      ts
    [return]    ${timestamp}

Get Slice Data From Event
    [Documentation]    delivers the slice data of pm data from event
    [Arguments]    ${event}
    ${kpi_event2}=    Get From Dictionary    ${event}         kpi_event2
    ${slice_data}=    Get From Dictionary    ${kpi_event2}    slice_data
    [return]    ${slice_data}

Validate Slice Data
    [Documentation]    validates passed slice data
    [Arguments]    ${slice}    ${metric_records}
    ${result}=       Set Variable    True
    ${checked}=      Set Variable    False
    ${device_id}=    Set Variable    ${EMPTY}
    ${title}=        Set Variable    ${EMPTY}
    ${SliceLength}=    Get Length    ${slice}
    FOR    ${Index}    IN RANGE    0    ${SliceLength}
        ${metadata}=    Get From Dictionary    ${slice[${Index}]}    metadata
        ${title}=    Get Title From Metadata    ${metadata}
        # workaround for wrong title in case of UniStatus -> UNI_Status, Girish is informed (31.03.2021)
        ${title}=    Set Variable If    '${title}'=='UniStatus'     UNI_Status      ${title}
        ${device_id}=    Get Device_Id From Metadata    ${metadata}
        Continue For Loop If    not '${device_id}' in ${METRIC_DICT}
        ${timestamp}=    Get Timestamp From Metadata    ${metadata}
        Run Keyword If     'PreviousRecord' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']}
        ...    Validate Timestamp    ${device_id}    ${title}    ${timestamp}    ${metric_records}    ${Index}
        ${metrics}=    Get From Dictionary    ${slice[${Index}]}    metrics
        Run Keyword If     'PreviousRecord' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']}
        ...            Validate Metrics Data With Previous   ${device_id}    ${title}    ${metrics}
        ...    ELSE    Validate Metrics Data   ${device_id}    ${title}    ${metrics}
        ${checked}=    Set Variable    True
    END
    # increase number of checks, only once per slice
    Run Keyword If    ${checked}    Increase Number of Checks    ${device_id}    ${title}

Validate Timestamp
    [Documentation]    validates passed timestamp with timestamp of previous metrics
    [Arguments]    ${device_id}    ${title}    ${timestamp}    ${metric_records}    ${SliceIndex}
    # get previous timestamp
    ${prev_timestamp}=   Get Previous Timestamp    ${METRIC_DICT['${device_id}']['MetricData']['${title}']['PreviousRecord']}
    ...    ${metric_records}    ${SliceIndex}
    ${interval}=    Get From Dictionary  ${METRIC_DICT['${device_id}']['MetricData']['${title}']['Intervals']}
    ...    current
    ${interval}=    Convert To Integer    ${interval}
    ${check_value}=     Evaluate    abs(${prev_timestamp}+${interval}-${timestamp})
    Run Keyword And Continue On Failure    Run Keyword Unless    ${0} <= ${check_value} <= ${4}    FAIL
    ...    Wrong interval for ${title} of device ${device_id}!

Validate Metrics Data
    [Documentation]    validates passed metrics
    [Arguments]    ${device_id}    ${title}    ${metrics}
    ${result}=    Set Variable    True

Validate Metrics Data With Previous
    [Documentation]    validates passed metrics with previous metrics
    [Arguments]    ${device_id}    ${title}    ${metrics}
    ${result}=    Set Variable    True

Get Previous Timestamp
    [Documentation]    deliveres the timestamp of the passed metrics record
    [Arguments]    ${prev_index}    ${metric_records}    ${SliceIndex}
    ${metric}=    Set Variable    ${metric_records[${prev_index}]}
    ${message}=    Get From Dictionary  ${metric}  message
    ${event}=    volthatools.Events Decode Event   ${message}    return_default=true
    ${slice}=    Get Slice Data From Event    ${event}
    ${metadata}=    Get From Dictionary    ${slice[${SliceIndex}]}    metadata
    ${timestamp}=    Get Timestamp From Metadata    ${metadata}
    [return]    ${timestamp}

Set Previous Record
    [Documentation]    sets the previous record in METRIC_DICT for next validation
    [Arguments]    ${Index}    ${slice}
    # use first slice for further handling
    ${metadata}=    Get From Dictionary    ${slice[${0}]}    metadata
    ${title}=    Get Title From Metadata    ${metadata}
    # workaround for wrong title in case of UniStatus -> UNI_Status, Girish is informed (31.03.2021)
    ${title}=    Set Variable If    '${title}'=='UniStatus'     UNI_Status      ${title}
    ${device_id}=    Get Device_Id From Metadata    ${metadata}
    Return From Keyword If    not '${device_id}' in ${METRIC_DICT}
    ${metric}=    Get From Dictionary     ${METRIC_DICT['${device_id}']['MetricData']}    ${title}
    Set To Dictionary    ${metric}    PreviousRecord=${Index}
    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']}    ${title}=${metric}

Increase Number of Checks
    [Documentation]    increases the NumberOfChecks value in METRIC_DICT for passed device id and title
    [Arguments]    ${device_id}    ${title}
    ${checks}=    Get From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    NumberOfChecks
    ${checks}=    evaluate    ${checks} + 1
    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    NumberOfChecks=${checks}

Validate Number of Checks
    [Documentation]    validates the NumberOfChecks value in METRIC_DICT, must be at least >=2
    [Arguments]    ${user}=False    ${group}=${EMPTY}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${device_id}=    Get Device ID From SN    ${src['onu']}
        ${list}=    Prepare Group Interval List per Device Id    ${device_id}    ${user}    ${group}
        Validate Number of Checks per Onu    ${device_id}    ${list}
    END

Validate Number of Checks per Onu
    [Documentation]    validates the NumberOfChecks value per ONU, must be at least >=2
    ...                Collecting of metrics will be calculated that at least each group has to be checked twice!
    [Arguments]    ${device_id}    ${list}
    FOR    ${Item}    IN    @{list}
        ${group}=    Get From Dictionary     ${Item}    group
        ${val}=      Get From Dictionary     ${Item}    interval
        # use interval value to skip groups, which should not be checked!
        Continue For Loop If    '${val}'=='-1'
        ${checks}=    Get From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']}    NumberOfChecks
        Run Keyword And Continue On Failure    Run Keyword Unless    ${2} <= ${checks}    FAIL
        ...    Wrong number of pm-data (${checks}) for ${group} of device ${device_id}!
    END

#################################################################
# Post test keywords
#################################################################

Remove Previous Record
    [Documentation]    removes the previous record in METRIC_DICT
    [Arguments]    ${device_id}    ${title}
    Remove From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    PreviousRecord

Reset Number Of Checks
    [Documentation]    removes the previous record in METRIC_DICT
    [Arguments]    ${device_id}    ${title}
    Set To Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${title}']}    NumberOfChecks=0

Clean Metric Dictionary per Onu
    [Documentation]    cleans metric dict per onu device id
    [Arguments]    ${device_id}
    FOR    ${Item}    IN     @{METRIC_DICT['${device_id}']['GroupList']}
        Remove Previous Record    ${device_id}    ${Item}
        Reset Number Of Checks    ${device_id}    ${Item}
    END

Clean Metric Dictionary
    [Documentation]    cleans metric dict
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        # read available metric groups
        Clean Metric Dictionary per Onu    ${onu_device_id}
    END
    log    ${METRIC_DICT}
