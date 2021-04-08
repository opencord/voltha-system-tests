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

Prepare Metrics List per Device Id
    [Documentation]    Prepares dummy metrics list per device id
    [Arguments]    ${dev_id}
    ${list}=    Get From Dictionary     ${METRIC_DICT['${dev_id}']}    GroupList
    ${metric_list}   Create List
    FOR    ${Item}    IN    @{list}
        ${dict}=     Create Dictionary    group=${Item}    interval=0
        Append To List    ${metric_list}    ${dict}
    END
    [return]   ${metric_list}

Get Onu Metrics Interval
    [Documentation]    Reads interval values per onu, default as well as per group
    [Arguments]    ${metric_list}=@{EMPTY}
    ${onu_interval_list}    Create List
    ${longest_interval}=    Set Variable    0
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}

        ${list}=    Run Keyword If    ${metric_list}!=@{EMPTY}    Set Variable    ${metric_list}
        ...         ELSE    Prepare Metrics List per Device Id    ${onu_device_id}

        ${onu_dict}    ${onu_longest_interval}=    Run Keyword If     '${onu_device_id}'!='${EMPTY}'
        ...    Get Metrics Interval per Onu    ${onu_device_id}    ${list}
        Append To List    ${onu_interval_list}    ${onu_dict}
        ${longest_interval}=    Set Variable If    ${onu_longest_interval} > ${longest_interval}    ${onu_longest_interval}
        ...    ${longest_interval}
    END
    [return]    ${onu_interval_list}    ${longest_interval}

Get Metrics Interval per Onu
    [Documentation]    Reads interval values of the given onu, default as well as per group
    ...                Stores all read values in onu_dict and return it.
    ...                Returns the longest interval of all groups
    [Arguments]    ${onu_device_id}     ${metric_list}
    ${onu_dict}    Create Dictionary    device_id    ${onu_device_id}
    ${default_interval}=        Read Default Interval From Pmconfig    ${onu_device_id}
    Set To Dictionary    ${onu_dict}    interval    ${default_interval}
    ${longest_interval}=    Set Variable    0
    ${group_list}   Create List
    FOR    ${Item}    IN    @{metric_list}
        ${group}=    Get From Dictionary     ${Item}    group
        ${val}=    Run Keyword IF     'interval' in ${Item}      Get From Dictionary     ${Item}    interval
        ...        ELSE               Set Variable    0
        Continue For Loop If    '${val}'=='-1'
        ${interval}=    Read Group Interval From Pmconfig    ${onu_device_id}    ${group}
        ${group_dict}=    Create Dictionary     group=${group}    interval=${interval}
        Append To List    ${group_list}    ${group_dict}
        ${interval}=    Get Substring    ${interval}    0    -1
        ${longest_interval}=    Set Variable If    ${interval} > ${longest_interval}    ${interval}    ${longest_interval}
    END
    Set To Dictionary    ${onu_dict}    group_list    ${group_list}
    [return]    ${onu_dict}    ${longest_interval}

Set And Validate Metrics Interval
    [Documentation]    Sets and validates interval of pm data for all onu
    [Arguments]    ${group_list}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Set And Validate Metrics Interval per Onu    ${onu_device_id}    ${ONU_DEFAULT_INTERVAL}    ${group_list}
    END

Set And Validate Previous Onu Metrics Interval
    [Documentation]    Sets previous (default) interval values of pm data per onu, default as well as per group
    [Arguments]    ${onu_interval_list}
    FOR    ${Item}    IN    @{onu_interval_list}
        ${onu_device_id}=     Get From Dictionary     ${Item}    device_id
        ${interval}=          Get From Dictionary     ${Item}    interval
        ${group_list}=        Get From Dictionary     ${Item}    group_list
        Set And Validate Metrics Interval per Onu    ${onu_device_id}    ${interval}    ${group_list}
    END

Set And Validate Metrics Interval per Onu
    [Documentation]    Sets and validates interval of pm data per onu
    [Arguments]    ${onu_device_id}    ${default_interval}    ${group_list}
    Set and Validate Default Interval    ${onu_device_id}    ${default_interval}
    FOR    ${Item}    IN    @{group_list}
        ${group}=    Get From Dictionary     ${Item}    group
        ${val}=      Get From Dictionary     ${Item}    interval
        Continue For Loop If    '${val}'=='-1'
        Set and Validate Group Interval      ${onu_device_id}    ${val}    ${group}
        # update current interval in METRICS_DICT
        ${metric}=    Get From Dictionary     ${METRIC_DICT['${onu_device_id}']['MetricData']}    ${group}
        ${intervals}    Get From Dictionary   ${metric}        Intervals
        ${val}=    Get Substring    ${val}    0    -1
        Set To Dictionary    ${intervals}    current=${val}
        Set To Dictionary    ${metric}    Intervals=${intervals}
        Set To Dictionary    ${METRIC_DICT['${onu_device_id}']['MetricData']}    ${group}=${metric}
    END

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

#################################################################
# test keywords
#################################################################

Get Metrics
    [Documentation]    Get metrics from kafka
    [Arguments]    ${duration}=${CollectionsDuration}    ${clear}=True
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
        ${tsresult}=    Run Keyword If     'PreviousRecord' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']}
        ...    Validate Timestamp    ${device_id}    ${title}    ${timestamp}    ${metric_records}    ${Index}
        ${metrics}=    Get From Dictionary    ${slice[${Index}]}    metrics
        ${valresult}=    Run Keyword If     'PreviousRecord' in ${METRIC_DICT['${device_id}']['MetricData']['${title}']}
        ...            Validate Metrics Data With Previous   ${device_id}    ${title}    ${metrics}
        ...    ELSE    Validate Metrics Data   ${device_id}    ${title}    ${metrics}
        ${checked}=    Set Variable    True
        ${result}=    Run Keyword If    ${result}    Set Variable If      ${tsresult} and ${valresult}    True    False
    END
    # increase number of checks, only once per slice
    Run Keyword If    ${checked}    Increase Number of Checks    ${device_id}    ${title}
    [return]    ${result}

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
    ${result}=    Set Variable If     ${0} <= ${check_value} <= ${4}    True    False
    Run Keyword And Continue On Failure    Run Keyword Unless    ${result}    FAIL
    ...    Wrong interval for ${title} of device ${device_id}!
    [return]    ${result}

Validate Metrics Data
    [Documentation]    validates passed metrics
    [Arguments]    ${device_id}    ${title}    ${metrics}
    ${result}=    Set Variable    True
    [return]    ${result}

Validate Metrics Data With Previous
    [Documentation]    validates passed metrics with previous metrics
    [Arguments]    ${device_id}    ${title}    ${metrics}
    ${result}=    Set Variable    True
    [return]    ${result}

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
    [Arguments]    ${metric_list}=@{EMPTY}
    ${result}=    Set Variable    True
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        ${list}=    Run Keyword If    ${metric_list}!=@{EMPTY}    Set Variable    ${metric_list}
        ...         ELSE    Prepare Metrics List per Device Id    ${onu_device_id}
        ${checkresult}=    Validate Number of Checks per Onu    ${onu_device_id}    ${list}
        ${result}=    Run Keyword If    ${result}    Set Variable If    ${checkresult}    True    False
    END
    [return]    ${result}

Validate Number of Checks per Onu
    [Documentation]    validates the NumberOfChecks value per ONU, must be at least >=2
    ...                Collecting of metrics will be calculated that at least each group has to be checked twice!
    [Arguments]    ${device_id}    ${metric_list}
    ${result}=    Set Variable    True
    FOR    ${Item}    IN    @{metric_list}
        ${group}=    Get From Dictionary     ${Item}    group
        ${checks}=    Get From Dictionary    ${METRIC_DICT['${device_id}']['MetricData']['${group}']}    NumberOfChecks
        ${checkresult}=    Set Variable If     ${2} <= ${checks}    True    False
        Run Keyword And Continue On Failure    Run Keyword Unless    ${checkresult}    FAIL
        ...    Wrong number of pm-data (${checks}) for ${group} of device ${device_id}!
        ${result}=    Run Keyword If    ${result}    Set Variable If    ${checkresult}    True    False
    END
    [return]    ${result}

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
