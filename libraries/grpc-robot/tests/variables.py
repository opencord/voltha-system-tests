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
