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
from grpc_robot.grpc_robot import _package_version_get

from dmi import hw_metrics_mgmt_service_pb2, hw_events_mgmt_service_pb2
from ..tools.protobuf_to_dict import protobuf_to_dict


class DmiTools(object):
    """
    Tools for the device-management-interface, e.g decoding / conversions.
    """

    try:
        ROBOT_LIBRARY_VERSION = _package_version_get('grpc_robot')
    except NameError:
        ROBOT_LIBRARY_VERSION = 'unknown'

    @staticmethod
    def hw_metrics_mgmt_decode_metric(bytestring, return_enum_integer='false', return_defaults='false', human_readable_timestamps='true'):
        """
        Converts bytes to a Metric as defined in _message Metric_ from hw_metrics_mgmt_service.proto

        *Parameters*:
        - bytestring: <bytes>; Byte string, e.g. as it comes from Kafka messages.
        - return_enum_integer: <string> or <bool>; Whether or not to return the enum values as integer values rather than their labels. Default: _false_.
        - return_defaults: <string> or <bool>; Whether or not to return the default values. Default: _false_.
        - human_readable_timestamps: <string> or <bool>; Whether or not to convert the timestamps to human-readable format. Default: _true_.

        *Return*: A dictionary with same structure as the _metric_ key from the return dictionary of keyword _Hw Metrics Mgmt Service Get Metric_.

        *Example*:
        | Import Library | grpc_robot.DmiTools | WITH NAME | dmi_tools |
        | ${kafka_records} | kafka.Records Get |
        | FOR | ${kafka_record} | IN | @{kafka_records} |
        |  | ${metric} | dmi_tools.Hw Metrics Mgmt Decode Metric | ${kafka_record}[message] |
        |  | Log | ${metric} |
        | END |
        """
        return_enum_integer = str(return_enum_integer).lower() == 'true'
        metric = hw_metrics_mgmt_service_pb2.Metric.FromString(bytestring)
        return protobuf_to_dict(metric,
                                use_enum_labels=not return_enum_integer,
                                including_default_value_fields=str(return_defaults).lower() == 'true',
                                human_readable_timestamps=str(human_readable_timestamps).lower() == 'true')

    @staticmethod
    def hw_events_mgmt_decode_event(bytestring, return_enum_integer='false', return_defaults='false', human_readable_timestamps='true'):
        """
        Converts bytes to a Event as defined in _message Event_ from hw_events_mgmt_service.proto

        *Parameters*:
        - bytestring: <bytes>; Byte string, e.g. as it comes from Kafka messages.
        - return_enum_integer: <string> or <bool>; Whether or not to return the enum values as integer values rather than their labels. Default: _false_.
        - return_defaults: <string> or <bool>; Whether or not to return the default values. Default: _false_.
        - human_readable_timestamps: <string> or <bool>; Whether or not to convert the timestamps to human-readable format. Default: _true_.

        *Return*: A dictionary with same structure as the _event_ key from the return dictionary of keyword _Hw Event Mgmt Service List Events_.

        *Example*:
        | Import Library | grpc_robot.DmiTools | WITH NAME | dmi_tools |
        | ${kafka_records} | kafka.Records Get |
        | FOR | ${kafka_record} | IN | @{kafka_records} |
        |  | ${event} | dmi_tools.Hw Events Mgmt Decode Event | ${kafka_record}[message] |
        |  | Log | ${event} |
        | END |
        """
        return_enum_integer = str(return_enum_integer).lower() == 'true'
        event = hw_events_mgmt_service_pb2.Event.FromString(bytestring)
        return protobuf_to_dict(event,
                                use_enum_labels=not return_enum_integer,
                                including_default_value_fields=str(return_defaults).lower() == 'true',
                                human_readable_timestamps=str(human_readable_timestamps).lower() == 'true')
