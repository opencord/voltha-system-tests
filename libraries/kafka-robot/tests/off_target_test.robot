*** Settings ***
Library           OperatingSystem    WITH NAME    os
Library           String

*** Test Cases ***
Library import
    Import Library    kafka_robot.KafkaClient    WITH NAME    kafka

Keywords
    Keyword Should Exist    kafka.Connection Close
    Keyword Should Exist    kafka.Connection Open
    Keyword Should Exist    kafka.Records Clear
    Keyword Should Exist    kafka.Records Get
    Keyword Should Exist    kafka.Subscribe
    Keyword Should Exist    kafka.Unsubscribe

Library Version
    ${lib_version}    kafka.Library Version Get
    ${pip show}    Run    python3 -m pip show kafka-robot | grep Version
    ${pip show}    Split To Lines    ${pip show}
    FOR    ${line}    IN    @{pip show}
        ${is_version}    Evaluate    '${line}'.startswith('Version')
        Continue For Loop If    not ${is_version}
        ${pip_version}    Evaluate    '${line}'.split(':')[-1].strip()
        Should Be Equal    ${pip_version}    ${lib_version}
    END
