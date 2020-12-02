from grpc_robot.grpc_robot import _package_version_get

from dmi import hw_metrics_mgmt_service_pb2
from protobuf_to_dict import protobuf_to_dict


class DmiTools(object):
    """
    Tools for the device-management-interface, e.g decoding / conversions.
    """

    try:
        ROBOT_LIBRARY_VERSION = _package_version_get('grpc_robot')
    except NameError:
        ROBOT_LIBRARY_VERSION = 'unknown'

    @staticmethod
    def hw_metrics_mgmt_decode_metric(bytestring, return_enum_integer='false'):
        """
        Converts bytes to a Metric as defined in _message Metric_ from hw_metrics_mgmt_service.proto

        *Parameters*:
        - bytestring: <bytes>; Byte string, e.g. as it comes from Kafka messages.
        - return_enum_integer: <bool> or <string>; Whether or not to return the enum values as integer values rather than their labels. Default: ${FALSE} or false.

        *Return*: A dictionary with same structure as the _metric_ key from the return dictionary of keyword _Hw Metrics Mgmt Service Get Metric_.

        *Example*:
        | Import Library | grpc_robot.DmiTools | WITH NAME | dmi_tools |
        | ${kafka_records} | kafka.Records Get |
        | FOR | ${kafka_record} | IN | @{kafka_records} |
        |  | ${metric} | dmi_tools.Hw Metrics Mgmt Decode Metric | ${kafka_record}[message] |
        |  | Log | ${metric} |
        | END |
        """
        return_enum_integer = bool(str(return_enum_integer).lower() == 'true')
        metric = hw_metrics_mgmt_service_pb2.Metric.FromString(bytestring)
        return protobuf_to_dict(metric, use_enum_labels=not return_enum_integer)
