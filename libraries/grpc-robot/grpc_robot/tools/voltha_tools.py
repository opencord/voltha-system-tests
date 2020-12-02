# Copyright 2021 ADTRAN, Inc.
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

from voltha_protos import events_pb2
from ..tools.protobuf_to_dict import protobuf_to_dict


class VolthaTools(object):
    """
    Tools for the voltha, e.g decoding / conversions.
    """

    try:
        ROBOT_LIBRARY_VERSION = _package_version_get('grpc_robot')
    except NameError:
        ROBOT_LIBRARY_VERSION = 'unknown'

    @staticmethod
    def events_decode_event(bytestring, return_enum_integer='false', return_defaults='false', human_readable_timestamps='true'):
        """
        Converts bytes to an Event as defined in _message Event_ from events.proto

        *Parameters*:
        - bytestring: <bytes>; Byte string, e.g. as it comes from Kafka messages.
        - return_enum_integer: <string> or <bool>; Whether or not to return the enum values as integer values rather than their labels. Default: _false_.
        - return_defaults: <string> or <bool>; Whether or not to return the default values. Default: _false_.
        - human_readable_timestamps: <string> or <bool>; Whether or not to convert the timestamps to human-readable format. Default: _true_.

        *Return*: A dictionary with _event_ structure.

        *Example*:
        | Import Library | grpc_robot.VolthaTools | WITH NAME | voltha_tools |
        | ${kafka_records} | kafka.Records Get |
        | FOR | ${kafka_record} | IN | @{kafka_records} |
        |  | ${event} | voltha_tools.Event Decode Event | ${kafka_record}[message] |
        |  | Log | ${event} |
        | END |
        """
        return_enum_integer = str(return_enum_integer).lower() == 'true'
        result = events_pb2.Event.FromString(bytestring)
        return protobuf_to_dict(result,
                                use_enum_labels=not return_enum_integer,
                                including_default_value_fields=str(return_defaults).lower() == 'true',
                                human_readable_timestamps=str(human_readable_timestamps).lower() == 'true')

