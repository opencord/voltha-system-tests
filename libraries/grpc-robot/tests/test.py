from grpc_robot import Dmi

dmi = Dmi()
dmi.connection_open(host='127.0.0.1', port='50051')

# print(dmi.library_version_get())
# print(dmi.dmi_version_get())
#
# kws = dmi.get_keyword_names()
# for kw in kws:
#     print('====>', kw)
#     print(dmi.get_keyword_arguments(kw))
#     print(dmi.get_keyword_documentation(kw))
# print(len(kws))
# print(dmi.get_keyword_documentation('sw_management_service_activate_image'))
# print(dmi.get_keyword_documentation('hw_event_mgmt_service_list_events'))
# print(dmi.get_keyword_documentation('hw_management_service_get_managed_devices'))
# print(dmi.get_keyword_documentation('hw_management_service_start_managing_device'))

# print(dmi.run_keyword('hw_event_mgmt_service_list_events', [{'uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_event_mgmt_service_update_events_configuration', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
#
# print(dmi.run_keyword('hw_management_service_start_managing_device', [{'name': 'otti', 'uri': {'uri': '1.2.3.4'}}], {}))
# print(dmi.run_keyword('hw_management_service_stop_managing_device', [{'name': 'otti'}], {}))
# print(dmi.run_keyword('hw_management_service_get_managed_devices', [], {}))
# print(dmi.run_keyword('hw_management_service_get_physical_inventory', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_management_service_get_hw_component_info', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_management_service_set_hw_component_info', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_management_service_set_logging_endpoint', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_management_service_get_logging_endpoint', [{'uuid': '1234-3456-5678'}], {}))
# print(dmi.run_keyword('hw_management_service_set_msg_bus_endpoint', [{'msgbus_endpoint': '1234-3456-5678'}], {}))
# print(dmi.run_keyword('hw_management_service_get_msg_bus_endpoint', [], {}))
# print(dmi.run_keyword('hw_management_service_get_loggable_entities', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_management_service_set_log_level', [{'device_uuid': {'uuid': '1234-3456-5678'}, 'loglevels': [{'logLevel': 'TRACE'}]}], {}))
# print(dmi.run_keyword('hw_management_service_get_log_level', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
#
# print(dmi.run_keyword('hw_metrics_mgmt_service_list_metrics', [{'uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_metrics_mgmt_service_update_metrics_configuration', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('hw_metrics_mgmt_service_get_metric', [{'meta_data': {'device_uuid': {'uuid': '1234-3456-5678'}}}], {}))
#
# print(dmi.run_keyword('sw_management_service_get_software_version', [{'uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('sw_management_service_download_image', [{'device_uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('sw_management_service_activate_image', [{'uuid': {'uuid': '1234-3456-5678'}}], {}))
# print(dmi.run_keyword('sw_management_service_revert_to_standby_image', [{'uuid': {'uuid': '1234-3456-5678'}}], {}))

dmi.connection_close()
