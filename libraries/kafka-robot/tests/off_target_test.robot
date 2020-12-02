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
Documentation    Library test suite for the kafka_robot library. Due to a missing Kafka server offline test can be
...    executed only.
Library    OperatingSystem    WITH NAME    os
Library    String

*** Test Cases ***
Library import
    [Documentation]    Checks if the kafka_robot library can be imported.
    Import Library    kafka_robot.KafkaClient    WITH NAME    kafka

Library Version
    [Documentation]    Determines the version of the installed package and compares it with the returned version of the
    ...    corresponding keyword.
    ${lib_version}    kafka.Library Version Get
    ${pip show}    Run    python3 -m pip show kafka-robot | grep Version
    ${pip show}    Split To Lines    ${pip show}
    FOR    ${line}    IN    @{pip show}
        ${is_version}    Evaluate    '${line}'.startswith('Version')
        Continue For Loop If    not ${is_version}
        ${pip_version}    Evaluate    '${line}'.split(':')[-1].strip()
        Should Be Equal    ${pip_version}    ${lib_version}
    END

Keywords
    [Documentation]    Checks if the keyword name exists in the library's keyword list.
    Keyword Should Exist    kafka.Connection Close
    Keyword Should Exist    kafka.Connection Open
    Keyword Should Exist    kafka.Records Clear
    Keyword Should Exist    kafka.Records Get
    Keyword Should Exist    kafka.Subscribe
    Keyword Should Exist    kafka.Unsubscribe
