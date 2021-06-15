from kafka_client import KafkaClient

k = KafkaClient(log_level='ERROR')

k.connection_open('1.2.3.4', '9093', 'dm_metric')
