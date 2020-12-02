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
import os
import ssl
import six
import json
import time
import uuid
import kafka
import getpass
import logging
import logging.config
import tempfile
import threading
import pkg_resources

from datetime import datetime
import robot
from robot.libraries.BuiltIn import BuiltIn, RobotNotRunningError
from robot.utils import robottime
from robot.api.deco import keyword


def _package_version_get(package_name, source=None):
    """
    Returns the installed version number for the given pip package with name _package_name_.
    """

    if source:
        head, tail = os.path.split(os.path.dirname(os.path.abspath(source)))

        while tail:
            try:
                with open(os.path.join(head, 'VERSION')) as version_file:
                    return version_file.read().strip()
            except Exception:
                head, tail = os.path.split(head)

    try:
        return pkg_resources.get_distribution(package_name).version
    except pkg_resources.DistributionNotFound:
        raise NameError("Package '%s' is not installed!" % package_name)


class FatalError(RuntimeError):
    ROBOT_EXIT_ON_FAILURE = True


class KafkaRecord(object):
    """
    Wrapper for Kafka message
    """

    def __init__(self, customer_record):
        self._org_record = customer_record

    @property
    def topic(self):
        return self._org_record.topic

    @property
    def value(self):
        return self._org_record.value

    @property
    def key(self):
        return self._org_record.key

    @property
    def offset(self):
        return self._org_record.offset

    @property
    def timestamp(self):
        return self._org_record.timestamp


class KafkaListener(threading.Thread):
    """
    Internal helper class used by this client.
    """

    def __init__(self, topic_name, callback, consumer, **kwargs):
        """
        - topic_name: The Kafka topic to be listened to
        - callback: The function to be executed when Kafka message arrives
        - consumer: The Kafka consumer object of type kafka.KafkaConsumer()
        - **kwargs: The keyword arguments:
            - timestamp_from: To be used in the callback function, description in KafkaClient.subscribe()
        """
        super(KafkaListener, self).__init__()

        self.setDaemon(True)

        self._topic = topic_name
        self._cb_func = callback
        self._consumer = consumer
        self._kwargs = kwargs
        self.id = str(uuid.uuid4()).replace('-', '')

        self.error = []

    def run(self):
        try:
            self._consumer.subscribe([self._topic])
            for record in self._consumer:
                try:
                    self._cb_func(KafkaRecord(record), **self._kwargs)
                except Exception as e:
                    logging.error('Error while deliver message: %s' % e)
                    self.stop()
        except Exception:
            pass

    def stop(self):
        if self._consumer is not None:
            self._close_consumer()

    def _close_consumer(self):
        # try:
        #     self._consumer.unsubscribe()
        # except Exception as e:
        #     self.error.append(str(e))
        #     print(self.error)

        try:
            self._consumer.close(autocommit=False)
        except Exception as e:
            self.error.append(str(e))


class KafkaClient(object):
    """ Constants """
    ROBOT_LIBRARY_VERSION = '0.0'
    ROBOT_LIBRARY_SCOPE = 'TEST SUITE'

    global_init = 0
    global_timeout = 120
    min_robot_version = 30202

    try:
        ROBOT_LIBRARY_VERSION = _package_version_get('kafka_robot')
    except NameError:
        ROBOT_LIBRARY_VERSION = 'unknown'

    def __init__(self, **kwargs):
        """
        Constructor
        """
        super(KafkaClient, self).__init__()
        self._record_list = []
        self._listeners = {}

        self._host = None
        self._port = None
        self._cert_path = None
        self._consumer = None
        self._consumer_config = kafka.KafkaConsumer.DEFAULT_CONFIG
        self._topic_name = None

        self._enable_logging(kwargs.get('root_logging', False), kwargs.get('log_level', 'INFO'))
        logging.getLogger('kafka').propagate = False
        self._log = logging.getLogger('kafka.conn')

        # set default ssl context to accept any (self signed) certificate
        ssl_ctx = ssl.create_default_context()
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE

        self._consumer_config['ssl_context'] = ssl_ctx

    def _check_robot_version(self, min_robot_version):
        """
        This method verifies the Min Robot version required to run

        *Parameter* :
            - min_robot_version : <string> ; Minimum robot version is: 20801

        *Return* : None if no errors else error message
        """

        if self._get_robot_version() < int(min_robot_version):
            raise FatalError('wrong robot version: %s' % robot.get_version())

    @staticmethod
    def _get_robot_version():
        """
        This method gets the Min Robot version required to run

        *Parameter* : None

        *Return* : None if no errors else error message
        """
        version = robot.get_version().split('.')
        if len(version) == 2:
            return int(version[0]) * 10000 + int(version[1]) * 100
        elif len(version) == 3:
            return int(version[0]) * 10000 + \
                   int(version[1]) * 100 + int(version[2])
        else:
            return 0

    @staticmethod
    def _robot_bool_convert(robot_bool):
        """
        Converts unicode to boolean or returns unchanged input variable if it is
        boolean already.

        :param robot_bool: value to be converted
        :return: Input param converted to boolean
        """
        real_bool = robot_bool
        if not isinstance(robot_bool, bool):
            robot_bool = str(robot_bool)
            if robot_bool.lower() == "true":
                real_bool = True
            else:
                real_bool = False
        return real_bool

    @keyword
    def library_version_get(self):
        """
        Retrieve the version of the currently running library instance.

        *Returns*: version string consisting of three dot-separated numbers (x.y.z)
        """
        return self.ROBOT_LIBRARY_VERSION

    def __del__(self):
        if self._host is not None:
            self.connection_close()

    @staticmethod
    def _enable_logging(root_logging, log_level):

        try:
            log_dir = BuiltIn().replace_variables('${OUTPUT_DIR}')
        except RobotNotRunningError:
            log_dir = tempfile.gettempdir()

        try:
            logfile_name = os.path.join(log_dir, 'kafka_robot_%s.log' % getpass.getuser())
        except KeyError:
            logfile_name = os.path.join(log_dir, 'kafka_robot.log')

        logging_dict = {
            'version': 1,
            'disable_existing_loggers': False,

            'formatters': {
                'standard': {
                    'format': '%(asctime)s  %(name)s [%(levelname)s] : %(message)s'
                }
            },
            'handlers': {
                'kafka_file': {
                    'level': log_level.upper(),
                    'class': 'logging.FileHandler',
                    'mode': 'w',
                    'filename': logfile_name,
                    'formatter': 'standard'
                }
            },
            'loggers': {
                'kafka': {
                    'handlers': ['kafka_file'],
                    'level': log_level.upper(),
                    'propagate': False
                }
            }
        }
        if not root_logging:
            logging_dict['loggers'].update({'': {'level': 'NOTSET'}})
        logging.config.dictConfig(logging_dict)

    def connection_open(self, host, port='9093', topic_name='', **kwargs):
        """
        Opens a connection to the Kafka host.

        *Parameters*:
        - host: <string>|<IP address>; Name or IP address of the Kafka host.
        - port: <number>; TCP port of the Kafka host. Default: 9093.
        - topic_name: <string>; The name of the topic to listen on; optional. If not set, the keyword _subscribe_ can be used to set the subscription.

        *Named parameters*:
        - timestamp_from: <time string>, 0: Timestamp string format YYYY-MM-DD hh:mm:ss
            (e.g. 2021-01-31 23:34:45) to define the time from which kafka records timestamps are collected in the
            record list. If 0 then the filtering is switched off and received Kafka records are collected. If
            _timestamp_from_ is not set then the library will use the current time for the filter.

        To set connection parameters such as certificates or authentication methods use _configuration_set_, e.g. for configuring ssl use

        | Configuration Set | ssl_cafile=nms_cachain.crt | ssl_certfile=nms_suite.crt | ssl_keyfile=nms_suite.key | ssl_check_hostname=${False} |

        *Return*: The ID of the subscription, if the parameter _topic_name_ is set. This ID can be used to unsubscribe.
        """
        self._host = host
        self._port = port

        self.configuration_set(bootstrap_servers='%s:%s' % (self._host, int(self._port)))

        if topic_name:
            return self.subscribe(topic_name=topic_name, **kwargs)

    def connection_close(self):
        """
        Closes the connection to the Kafka host. Stops all running listener to Kafka subscriptions.
        """
        for _, l in self._listeners.items():
            l.stop()

        self._host = None
        self._port = None
        self._cert_path = None

    @staticmethod
    def _get_timestamp(timestamp):

        if timestamp is None or timestamp == '':
            timestamp = datetime.now()

        try:
            timestamp = int(time.mktime(datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S').timetuple()) * 1000)
        except TypeError:
            try:
                timestamp = int(time.mktime(timestamp.timetuple()) * 1000)
            except AttributeError:
                timestamp = int(timestamp)
        except ValueError:
            try:
                timestamp = int(timestamp)
            except ValueError:
                raise ValueError('"%s" is not a valid input: should be of format "YYYY-MM-DD hh:mm:ss"' % timestamp)

        return timestamp

    def subscribe(self, topic_name, **kwargs):  # type: (str) -> str
        """
        Subscribe for an external topic and starts a listener on this topic. All records received in this listener are
        stored in a record list, which can be retrieved with keyword _records_get_. Records are recorded until it is
        unsubscribed from the topic.

        *Parameters*:
        - topic_name: <string>; The name of the topic to listen on.

        *Named parameters*:
        - timestamp_from: <time string>, 0: Timestamp string format YYYY-MM-DD hh:mm:ss
            (e.g. 2021-01-31 23:34:45) to define the time from which kafka records timestamps are collected in the
            record list. If 0 then the filtering is switched off and received Kafka records are collected. If
            _timestamp_from_ is not set then the library will use the current time for the filter.
        - human_readable_timestamps:

        *Return*: The ID of the subscription. This ID can be used to unsubscribe.
        """
        kwargs['timestamp_from'] = self._get_timestamp(kwargs.get('timestamp_from'))

        consumer = self._create_consumer()
        listener = KafkaListener(topic_name=topic_name, callback=self._add_record, consumer=consumer, **kwargs)  # type: KafkaListener
        self._listeners[listener.id] = listener
        listener.start()
        return listener.id

    def unsubscribe(self, subscription_id):
        """
        Stops the listener and unsubscribes from an external topic.

        *Parameters*:
         - subscription_id: <string>; Subscription ID got from keyword _subscribe_.
        """
        listener = self._listeners.get(subscription_id)  # type: KafkaListener
        if listener is not None:
            listener.stop()
            del self._listeners[subscription_id]

            if listener.error:
                raise Exception(', '.join(listener.error))

    def _records_wait_for(self, topic_name, number_of_records, wait_time='0', require_number_of_records='true'):
        """
        A lock function that waits for the specified _number_of_records_ on a topic or until the _wait_time_
        is expired. The keyword subscribes for the Kafka topic. So it is not necessary to subscribe with the
        _Subscribe_ keyword before.

        *Parameter*:
        - topic_name: <string>; The name of the topic to listen on.
        - number_of_records: <number>; Number of records to be waited for.
        - wait_time: <string>; Time to wait for the records. Default: _0_. If _0_ then the keyword waits forever for
                the number of records, if not _0_ then it waits at maximum _wait_time_.
        - require_number_of_records: _false_, _true_; Whether or not to check if list to return contains number of
                records. If not an AssertionError is raised.

        *Return*: A list of dictionaries. Each dictionary represents a record and consists of keys:
        - topic: Name of the topic
        - timestamp: Number of seconds since Jan 01 1970 (UTC)
        - message: Message content as dictionary
        """
        return_list = []

        consumer = self._create_consumer()
        consumer.subscribe(topics=[topic_name])
        records = consumer.poll(timeout_ms=1000 * robottime.timestr_to_secs(wait_time), max_records=int(number_of_records))
        consumer.unsubscribe()
        consumer.close(autocommit=False)

        for _, v in records.items():
            return_list.extend(v)

        if require_number_of_records == 'true':
            if len(return_list) != number_of_records:
                raise AssertionError('returned list does not contain expected number of records')

        return [json.loads(r.value) for r in return_list]

    def records_get(self, topic_name='all'):
        """
        Retrieves the list of records for subscribed topics.

        *Parameters*:
        - topic_name: <string>, _all_; The name of the topic to retrieve from record list. Default: _all_.

        *Return*: A list of dictionaries. Each dictionary represents a record and consists of keys:
        - topic: Name of the topic
        - timestamp: Number of milliseconds since Jan 01 1970, midnight (UTC) as string format "yyyy-mm-dd hh:MM:ss.ffffff"
        - message: Message content as dictionary
        """
        if not topic_name or topic_name == 'all':
            return self._record_list
        else:
            return [r for r in self._record_list if r.get('topic') == topic_name]

    def records_clear(self, topic_name='all'):
        """
        Clears the list of records for subscribed topics.

        *Parameters*:
        - topic_name: <string>, _all_; The name of the topic to remove from record list. Default: _all_.
        """
        if not topic_name or topic_name == 'all':
            self._record_list = []
        else:
            self._record_list = [r for r in self._record_list if r.get('topic') != topic_name]

    def configuration_set(self, **kwargs):
        """
        Available setting with example values. To get actual used setting use _Configuration Get_.
        Values must be supplied using there correct type (e.g. int, str, bool)

        - 'bootstrap_servers': 'localhost',
        - 'client_id': 'kafka-python-' + __version__,
        - 'group_id': None,
        - 'key_deserializer': None,
        - 'value_deserializer': None,
        - 'fetch_max_wait_ms': 500,
        - 'fetch_min_bytes': 1,
        - 'fetch_max_bytes': 52428800,
        - 'max_partition_fetch_bytes': 1 * 1024 * 1024,
        - 'request_timeout_ms': 305000, # chosen to be higher than the default of max_poll_interval_ms
        - 'retry_backoff_ms': 100,
        - 'reconnect_backoff_ms': 50,
        - 'reconnect_backoff_max_ms': 1000,
        - 'max_in_flight_requests_per_connection': 5,
        - 'auto_offset_reset': 'latest',
        - 'enable_auto_commit': True,
        - 'auto_commit_interval_ms': 5000,
        - 'default_offset_commit_callback': lambda offsets, response: True,
        - 'check_crcs': True,
        - 'metadata_max_age_ms': 5 * 60 * 1000,
        - 'partition_assignment_strategy': (RangePartitionAssignor, RoundRobinPartitionAssignor),
        - 'max_poll_records': 500,
        - 'max_poll_interval_ms': 300000,
        - 'session_timeout_ms': 10000,
        - 'heartbeat_interval_ms': 3000,
        - 'receive_buffer_bytes': None,
        - 'send_buffer_bytes': None,
        - 'socket_options': [(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)],
        - 'consumer_timeout_ms': float('inf'),
        - 'skip_double_compressed_messages': False,
        - 'security_protocol': 'PLAINTEXT',
        - 'ssl_context': None,
        - 'ssl_check_hostname': True,
        - 'ssl_cafile': None,
        - 'ssl_certfile': None,
        - 'ssl_keyfile': None,
        - 'ssl_crlfile': None,
        - 'ssl_password': None,
        - 'api_version': None,
        - 'api_version_auto_timeout_ms': 2000,
        - 'connections_max_idle_ms': 9 * 60 * 1000,
        - 'metric_reporters': [],
        - 'metrics_num_samples': 2,
        - 'metrics_sample_window_ms': 30000,
        - 'metric_group_prefix': 'consumer',
        - 'selector': selectors.DefaultSelector,
        - 'exclude_internal_topics': True,
        - 'sasl_mechanism': None,
        - 'sasl_plain_username': None,
        - 'sasl_plain_password': None,
        - 'sasl_kerberos_service_name': 'kafka'
        """

        for key, value in six.iteritems(kwargs):
            self._consumer_config[key] = value

            # disable default ssl context if user configures a ssl setting
            if key.startswith('ssl') and key != 'ssl_context':
                self._consumer_config['ssl_context'] = None

    def configuration_get(self):
        """
        Shows the current setting of the Kafka interface. For available keys check keyword _Configuration Set_
        """
        return self._consumer_config

    def _add_record(self, record, **kwargs):
        try:

            if kwargs.get('timestamp_from') == 0 or kwargs.get('timestamp_from') <= record.timestamp:

                record = {
                    'topic': record.topic,
                    'timestamp': datetime.fromtimestamp(int(record.timestamp) / 1e3).strftime('%Y-%m-%d %H:%M:%S.%f'),
                    'timestamp_sec': record.timestamp,
                    'message': record.value
                }

                if record not in self._record_list:
                    self._record_list.append(record)

        except Exception as e:
            self._log.error(e)

    def _create_consumer(self):
        return kafka.KafkaConsumer(**self._consumer_config)
