*** Settings ***
Test Setup        kafka.Connection Open    ${HOST}
Test Teardown     kafka.Connection Close
Library           kafka_robot.KafkaClient    WITH NAME    kafka

*** Variables ***
${HOST}         10.160.50.195
${TOPIC_NAME}     ocean-topic

*** Test Cases ***
subscription
    ${subscription_id}    kafka.Subscribe    ${TOPIC_NAME}
    FOR    ${i}    IN RANGE    0    360
        Sleep    5s
        ${records}    kafka.Records Get
        ${len}    Get Length    ${records}
        Log    ${len}
    END
    [Teardown]    kafka.Unsubscribe    ${subscription_id}
