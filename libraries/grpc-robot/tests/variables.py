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

keywords_to_skip = [
    'connection_open',
    'connection_close',
    'connection_parameters_get',
    'connection_parameters_set',
    'get_keyword_names',
    'library_version_get',
    'dmi_version_get'
]

param_dicts = {
    'hw_event_mgmt_service_list_events': {'uuid': {'uuid': '1234-3456-5678'}},
    'hw_event_mgmt_service_update_events_configuration': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_start_managing_device': {'name': 'otti', 'uri': {'uri': '1.2.3.4'}},
    'hw_management_service_stop_managing_device': {'name': 'otti'},
    'hw_management_service_get_managed_devices': None,
    'hw_management_service_get_physical_inventory': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_get_hw_component_info': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_set_hw_component_info': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_set_logging_endpoint': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_get_logging_endpoint': {'uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_set_msg_bus_endpoint': {'msgbus_endpoint': '1234-3456-5678'},
    'hw_management_service_get_msg_bus_endpoint': None,
    'hw_management_service_get_loggable_entities': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_set_log_level': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_management_service_get_log_level': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_metrics_mgmt_service_list_metrics': {'uuid': {'uuid': '1234-3456-5678'}},
    'hw_metrics_mgmt_service_update_metrics_configuration': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'hw_metrics_mgmt_service_get_metric': {'meta_data': {'device_uuid': {'uuid': '1234-3456-5678'}}},
    'sw_management_service_get_software_version': {'uuid': {'uuid': '1234-3456-5678'}},
    'sw_management_service_download_image': {'device_uuid': {'uuid': '1234-3456-5678'}},
    'sw_management_service_activate_image': {'uuid': {'uuid': '1234-3456-5678'}},
    'sw_management_service_revert_to_standby_image': {'uuid': {'uuid': '1234-3456-5678'}},
    'sw_management_service_update_startup_configuration': {'device_uuid': {'uuid': '1234-3456-5678'}},
}

kafka_metric_messages = [
    {
        'message': b"\x08e\x12Y\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$96f716bd-9e72-5c39-9a79-58bb3821df19\x1a\x07cpu 0/1\x1a9\x08\x07\x10\x01\x18\t(\x012\x07percent:\x06\x08\xde\x96\x84\xfd\x05@\x88'J\x1bMETRIC_CPU_USAGE_PERCENTAGE",
        'metric': 'METRIC_CPU_USAGE_PERCENTAGE'
    },
    {
        'message': b"\x08\xaf\x02\x12f\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$f14853c0-51e8-5f5a-8983-e8dc9c060f5d\x1a\x14storage-resource 0/1\x1a:\x08_\x10\x01\x18\t(\x012\x07percent:\x06\x08\xe3\x96\x84\xfd\x05@\x88'J\x1cMETRIC_DISK_USAGE_PERCENTAGE",
        'metric': 'METRIC_DISK_USAGE_PERCENTAGE'
    },
    {
        'message': b"\x08\xf6\x03\x12b\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$81ba5a6b-b8b9-582e-9cea-a512ed6bd8ad\x1a\x10power-supply 0/1\x1a;\x082\x10\x01\x18\t(\x012\x07percent:\x06\x08\xe7\x96\x84\xfd\x05@\x88'J\x1dMETRIC_POWER_USAGE_PERCENTAGE",
        'metric': 'METRIC_POWER_USAGE_PERCENTAGE'
    },
    {
        'message': b"\x08\xf6\x03\x12b\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$760d33cd-ad0d-541b-8014-272af0cfbff8\x1a\x10power-supply 0/2\x1a;\x082\x10\x01\x18\t(\x012\x07percent:\x06\x08\xe7\x96\x84\xfd\x05@\x88'J\x1dMETRIC_POWER_USAGE_PERCENTAGE",
        'metric': 'METRIC_POWER_USAGE_PERCENTAGE'
    },
    {
        'message': b"\x08\x01\x12e\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$0f3a8a29-2b79-560a-a034-2255e0c85920\x1a\x13pluggable-fan 0/1/1\x1a+\x08\xc0%\x10\n\x18\t(\x012\x03rpm:\x06\x08\xeb\x96\x84\xfd\x05@\x88'J\x10METRIC_FAN_SPEED",
        'metric': 'METRIC_FAN_SPEED'
    },
    {
        'message': b"\x08\x01\x12e\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$80d0e158-efc0-59ea-808d-e273d1c46099\x1a\x13pluggable-fan 0/1/2\x1a+\x08\xe5&\x10\n\x18\t(\x012\x03rpm:\x06\x08\xeb\x96\x84\xfd\x05@\x88'J\x10METRIC_FAN_SPEED",
        'metric': 'METRIC_FAN_SPEED'
    },
    {
        'message': b"\x08\x01\x12e\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$15d3103a-36b2-5774-ae06-d2d59a2ab6e7\x1a\x13pluggable-fan 0/1/3\x1a+\x08\xc8$\x10\n\x18\t(\x012\x03rpm:\x06\x08\xeb\x96\x84\xfd\x05@\x88'J\x10METRIC_FAN_SPEED",
        'metric': 'METRIC_FAN_SPEED'
    },
    {
        'message': b"\x08\xd8\x04\x12a\n&\n$4c411df2-22e6-58d2-b1bb-545a0263d18d\x12&\n$dc8c95f1-6b84-5e6d-b645-c76b02b7551b\x1a\x0ftemperature 0/1\x1aB\x085\x10\x08\x18\t(\x012\x0edegree Celsius:\x06\x08\xf0\x96\x84\xfd\x05@\x88'J\x1dMETRIC_INNER_SURROUNDING_TEMP",
        'metric': 'METRIC_INNER_SURROUNDING_TEMP'
    },
]

kafka_event_messages = [
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf7\x03\x1a\x06\x08\x80\x82\xcd\xfe\x05"\x10\n\x02\x10\x00\x12\n\n\x08\n\x02'
                    b'\x10A\x12\x02\x10\x01',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_CRITICAL_RECOVERED'
    },
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf8\x03\x1a\x06\x08\x80\x82\xcd\xfe\x05"\x00',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_FATAL_RECOVERED'
    },
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf5\x03\x1a\x06\x08\xfe\xac\xdd\xfe\x05"\x10\n\x02\x10\x03\x12\n\n\x08\n\x02'
                    b'\x10\x02\x12\x02\x10\x01*\xcf\x01The system temperature of the physical entity '
                    b'\'temperature 0/1\' has risen above power reduction active-threshold of 2 degree Celsius. Unit '
                    b'operates out of specification. Correct service cannot be guaranteed.',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_CRITICAL'
    },
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf6\x03\x1a\x06\x08\xfe\xac\xdd\xfe\x05"\x00*\x86\x01The system temperature '
                    b'of the physical entity \'temperature 0/1\' has risen above thermal shutdown active-threshold '
                    b'of 2 degree Celsius.',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_FATAL'
    },
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf7\x03\x1a\x06\x08\xfe\xac\xdd\xfe\x05"\x10\n\x02\x10\x00\x12\n\n\x08\n\x02'
                    b'\x10\x02\x12\x02\x10\x01',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_CRITICAL_RECOVERED'
    },
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf5\x03\x1a\x06\x08\xfe\xac\xdd\xfe\x05"\x10\n\x02\x10\x03\x12\n\n\x08\n\x02'
                    b'\x10\x02\x12\x02\x10\x01*\xcf\x01The system temperature of the physical entity '
                    b'\'temperature 0/1\' has risen above power reduction active-threshold of 2 degree Celsius. Unit '
                    b'operates out of specification. Correct service cannot be guaranteed.',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_CRITICAL'
    },
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf7\x03\x1a\x06\x08\xfe\xac\xdd\xfe\x05"\x10\n\x02\x10\x00\x12\n\n\x08\n\x02'
                    b'\x10\x02\x12\x02\x10\x01',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_CRITICAL_RECOVERED'
    },
    {
        'message': b'\na\n&\n$84f46fde-89fa-5a2f-be4a-6d18abe6e953\x12&\n$368c6f41-564c-5821-8e15-721f818387fc\x1a\x0f'
                    b'temperature 0/1\x10\xf5\x03\x1a\x06\x08\xfe\xac\xdd\xfe\x05"\x10\n\x02\x10\x03\x12\n\n\x08\n\x02'
                    b'\x10\x02\x12\x02\x10\x01*\xcf\x01The system temperature of the physical entity '
                    b'\'temperature 0/1\' has risen above power reduction active-threshold of 2 degree Celsius. Unit '
                    b'operates out of specification. Correct service cannot be guaranteed.',
        'event': 'EVENT_HW_DEVICE_TEMPERATURE_ABOVE_CRITICAL'
    },
]
