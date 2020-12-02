# Robot Framework package for Kafka interface

This package allows receiving messages from a Kafka event stream in Robot Framework.

List of keywords: [kafka_robot.KafkaClient](docs/kafka_client.html). The list of keywords may be extended by request.

This library has a reduced range of functions. Please check if 
[robotframework-kafkalibrary](https://pypi.org/project/robotframework-kafkalibrary/) could be an alternative.

## Installation:

    pip install kafka-robot

## How to use _kafka-robot_ in Robot Framework:

    Import Library    kafka_robot.KafkaClient    WITH NAME    kafka
