# Copyright 2020-present Open Networking Foundation
# Original copyright 2020-present ADTRAN, Inc.
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
from robot.api.deco import keyword
from grpc_robot.services.service import is_connected

from grpc_robot.services.service import Service
from voltha_protos import voltha_pb2_grpc, voltha_pb2, common_pb2, openflow_13_pb2


class VolthaService(Service):

    prefix = 'voltha_service_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=voltha_pb2_grpc.VolthaServiceStub)

    # rpc GetMembership(google.protobuf.Empty) returns(Membership) {...};
    @keyword
    @is_connected
    def voltha_service_get_membership(self, **kwargs):
        return self._grpc_helper(self.stub.GetMembership, **kwargs)

    # rpc UpdateMembership(Membership) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_update_membership(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateMembership, voltha_pb2.Membership, param_dict, **kwargs)

    # rpc GetVoltha(google.protobuf.Empty) returns(Voltha) {...};
    @keyword
    @is_connected
    def voltha_service_get_voltha(self, **kwargs):
        return self._grpc_helper(self.stub.GetVoltha, **kwargs)

    # rpc ListCoreInstances(google.protobuf.Empty) returns(CoreInstances) {...};
    @keyword
    @is_connected
    def voltha_service_list_core_instances(self, **kwargs):
        return self._grpc_helper(self.stub.ListCoreInstances, **kwargs)

    # rpc GetCoreInstance(common.ID) returns(CoreInstance) {...};
    @keyword
    @is_connected
    def voltha_service_get_core_instance(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetCoreInstance, common_pb2.ID, param_dict, **kwargs)

    # rpc ListAdapters(google.protobuf.Empty) returns(Adapters) {...};
    @keyword
    @is_connected
    def voltha_service_list_adapters(self, **kwargs):
        return self._grpc_helper(self.stub.ListAdapters, **kwargs)

    # rpc ListLogicalDevices(google.protobuf.Empty) returns(LogicalDevices) {...};
    @keyword
    @is_connected
    def voltha_service_list_logical_devices(self, **kwargs):
        return self._grpc_helper(self.stub.ListLogicalDevices, **kwargs)

    # rpc GetLogicalDevice(common.ID) returns(LogicalDevice) {...};
    @keyword
    @is_connected
    def voltha_service_get_logical_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetLogicalDevice, common_pb2.ID, param_dict, **kwargs)

    # rpc ListLogicalDevicePorts(common.ID) returns(LogicalPorts) {...};
    @keyword
    @is_connected
    def voltha_service_list_logical_device_ports(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListLogicalDevicePorts, common_pb2.ID, param_dict, **kwargs)

    # rpc GetLogicalDevicePort(LogicalPortId) returns(LogicalPort) {...};
    @keyword
    @is_connected
    def voltha_service_get_logical_device_port(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetLogicalDevicePort, voltha_pb2.LogicalPortId, param_dict, **kwargs)

    # rpc EnableLogicalDevicePort(LogicalPortId) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_enable_logical_device_port(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.EnableLogicalDevicePort, voltha_pb2.LogicalPortId, param_dict, **kwargs)

    # rpc DisableLogicalDevicePort(LogicalPortId) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_disable_logical_device_port(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DisableLogicalDevicePort, voltha_pb2.LogicalPortId, param_dict, **kwargs)

    # rpc ListLogicalDeviceFlows(common.ID) returns(openflow_13.Flows) {...};
    @keyword
    @is_connected
    def voltha_service_list_logical_device_flows(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListLogicalDeviceFlows, common_pb2.ID, param_dict, **kwargs)

    # rpc UpdateLogicalDeviceFlowTable(openflow_13.FlowTableUpdate) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_update_logical_device_flow_table(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateLogicalDeviceFlowTable, openflow_13_pb2.FlowTableUpdate, param_dict, **kwargs)

    # rpc UpdateLogicalDeviceMeterTable(openflow_13.MeterModUpdate) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_update_logical_device_meter_table(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateLogicalDeviceMeterTable, openflow_13_pb2.MeterModUpdate, param_dict, **kwargs)

    # rpc ListLogicalDeviceMeters(common.ID) returns (openflow_13.Meters) {...};
    @keyword
    @is_connected
    def voltha_service_list_logical_device_meters(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListLogicalDeviceMeters, common_pb2.ID, param_dict, **kwargs)

    # rpc ListLogicalDeviceFlowGroups(common.ID) returns(openflow_13.FlowGroups) {...};
    @keyword
    @is_connected
    def voltha_service_list_logical_device_flow_groups(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListLogicalDeviceFlowGroups, common_pb2.ID, param_dict, **kwargs)

    # rpc UpdateLogicalDeviceFlowGroupTable(openflow_13.FlowGroupTableUpdate) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_update_logical_device_flow_group_table(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateLogicalDeviceFlowGroupTable, openflow_13_pb2.FlowGroupTableUpdate, param_dict, **kwargs)

    # rpc ListDevices(google.protobuf.Empty) returns(Devices) {...};
    @keyword
    @is_connected
    def voltha_service_list_devices(self, **kwargs):
        return self._grpc_helper(self.stub.ListDevices, **kwargs)

    # rpc ListDeviceIds(google.protobuf.Empty) returns(common.IDs) {...};
    @keyword
    @is_connected
    def voltha_service_list_device_ids(self, **kwargs):
        return self._grpc_helper(self.stub.ListDeviceIds, **kwargs)

    # rpc ReconcileDevices(common.IDs) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_reconcile_devices(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ReconcileDevices, common_pb2.IDs, param_dict, **kwargs)

    # rpc GetDevice(common.ID) returns(Device) {...};
    @keyword
    @is_connected
    def voltha_service_get_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetDevice, common_pb2.ID, param_dict, **kwargs)

    # rpc CreateDevice(Device) returns(Device) {...};
    @keyword
    @is_connected
    def voltha_service_create_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.CreateDevice, voltha_pb2.Device, param_dict, **kwargs)

    # rpc EnableDevice(common.ID) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_enable_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.EnableDevice, common_pb2.ID, param_dict, **kwargs)

    # rpc DisableDevice(common.ID) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_disable_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DisableDevice, common_pb2.ID, param_dict, **kwargs)

    # rpc RebootDevice(common.ID) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_reboot_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.RebootDevice, common_pb2.ID, param_dict, **kwargs)

    # rpc DeleteDevice(common.ID) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_delete_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DeleteDevice, common_pb2.ID, param_dict, **kwargs)

    # rpc ForceDeleteDevice(common.ID) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_force_delete_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ForceDeleteDevice, common_pb2.ID, param_dict, **kwargs)

    # rpc DownloadImage(ImageDownload) returns(common.OperationResp) {...};
    @keyword
    @is_connected
    def voltha_service_download_image(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DownloadImage, voltha_pb2.ImageDownload, param_dict, **kwargs)

    # rpc GetImageDownloadStatus(ImageDownload) returns(ImageDownload) {...};
    @keyword
    @is_connected
    def voltha_service_get_image_download_status(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetImageDownloadStatus, voltha_pb2.ImageDownload, param_dict, **kwargs)

    # rpc GetImageDownload(ImageDownload) returns(ImageDownload) {...};
    @keyword
    @is_connected
    def voltha_service_get_image_download(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetImageDownload, voltha_pb2.ImageDownload, param_dict, **kwargs)

    # rpc ListImageDownloads(common.ID) returns(ImageDownloads) {...};
    @keyword
    @is_connected
    def voltha_service_list_image_downloads(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListImageDownloads, common_pb2.ID, param_dict, **kwargs)

    # rpc CancelImageDownload(ImageDownload) returns(common.OperationResp) {...};
    @keyword
    @is_connected
    def voltha_service_cancel_image_download(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.CancelImageDownload, voltha_pb2.ImageDownload, param_dict, **kwargs)

    # rpc ActivateImageUpdate(ImageDownload) returns(common.OperationResp) {...};
    @keyword
    @is_connected
    def voltha_service_activate_image_update(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ActivateImageUpdate, voltha_pb2.ImageDownload, param_dict, **kwargs)

    # rpc RevertImageUpdate(ImageDownload) returns(common.OperationResp) {...};
    @keyword
    @is_connected
    def voltha_service_revert_image_update(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.RevertImageUpdate, voltha_pb2.ImageDownload, param_dict, **kwargs)

    # rpc ListDevicePorts(common.ID) returns(Ports) {...};
    @keyword
    @is_connected
    def voltha_service_list_device_ports(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListDevicePorts, common_pb2.ID, param_dict, **kwargs)

    # rpc ListDevicePmConfigs(common.ID) returns(PmConfigs) {...};
    @keyword
    @is_connected
    def voltha_service_list_device_pm_configs(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListDevicePmConfigs, common_pb2.ID, param_dict, **kwargs)

    # rpc UpdateDevicePmConfigs(voltha.PmConfigs) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_update_device_pm_configs(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateDevicePmConfigs, voltha_pb2.PmConfigs, param_dict, **kwargs)

    # rpc ListDeviceFlows(common.ID) returns(openflow_13.Flows) {...};
    @keyword
    @is_connected
    def voltha_service_list_device_flows(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListDeviceFlows, common_pb2.ID, param_dict, **kwargs)

    # rpc ListDeviceFlowGroups(common.ID) returns(openflow_13.FlowGroups) {...};
    @keyword
    @is_connected
    def voltha_service_list_device_flow_groups(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListDeviceFlowGroups, common_pb2.ID, param_dict, **kwargs)

    # rpc ListDeviceTypes(google.protobuf.Empty) returns(DeviceTypes) {...};
    @keyword
    @is_connected
    def voltha_service_list_device_types(self, **kwargs):
        return self._grpc_helper(self.stub.ListDeviceTypes, **kwargs)

    # rpc GetDeviceType(common.ID) returns(DeviceType) {...};
    @keyword
    @is_connected
    def voltha_service_get_device_type(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetDeviceType, common_pb2.ID, param_dict, **kwargs)

    # rpc ListDeviceGroups(google.protobuf.Empty) returns(DeviceGroups) {...};
    @keyword
    @is_connected
    def voltha_service_list_device_groups(self, **kwargs):
        return self._grpc_helper(self.stub.ListDeviceGroups, **kwargs)

    # rpc StreamPacketsOut(stream openflow_13.PacketOut) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_stream_packets_out(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.StreamPacketsOut, openflow_13_pb2.PacketOut, param_dict, **kwargs)

    # rpc ReceivePacketsIn(google.protobuf.Empty) returns(stream openflow_13.PacketIn) {...};
    @keyword
    @is_connected
    def voltha_service_receive_packets_in(self, **kwargs):
        return self._grpc_helper(self.stub.ReceivePacketsIn, **kwargs)

    # rpc ReceiveChangeEvents(google.protobuf.Empty) returns(stream openflow_13.ChangeEvent) {...};
    @keyword
    @is_connected
    def voltha_service_receive_change_events(self, **kwargs):
        return self._grpc_helper(self.stub.ReceiveChangeEvents, **kwargs)

    # rpc GetDeviceGroup(common.ID) returns(DeviceGroup) {...};
    @keyword
    @is_connected
    def voltha_service_get_device_group(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetDeviceGroup, common_pb2.ID, param_dict, **kwargs)

    # rpc CreateEventFilter(EventFilter) returns(EventFilter) {...};
    @keyword
    @is_connected
    def voltha_service_create_event_filter(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.CreateEventFilter, voltha_pb2.EventFilter, param_dict, **kwargs)

    # rpc GetEventFilter(common.ID) returns(EventFilters) {...};
    @keyword
    @is_connected
    def voltha_service_get_event_filter(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetEventFilter, common_pb2.ID, param_dict, **kwargs)

    # rpc UpdateEventFilter(EventFilter) returns(EventFilter) {...};
    @keyword
    @is_connected
    def voltha_service_update_event_filter(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateEventFilter, voltha_pb2.EventFilter, param_dict, **kwargs)

    # rpc DeleteEventFilter(EventFilter) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_delete_event_filter(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DeleteEventFilter, voltha_pb2.EventFilter, param_dict, **kwargs)

    # rpc ListEventFilters(google.protobuf.Empty) returns(EventFilters) {...};
    @keyword
    @is_connected
    def voltha_service_list_event_filters(self, **kwargs):
        return self._grpc_helper(self.stub.ListEventFilters, **kwargs)

    # rpc GetImages(common.ID) returns(Images) {...};
    @keyword
    @is_connected
    def voltha_service_get_images(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetImages, common_pb2.ID, param_dict, **kwargs)

    # rpc SelfTest(common.ID) returns(SelfTestResponse) {...};
    @keyword
    @is_connected
    def voltha_service_self_test(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SelfTest, common_pb2.ID, param_dict, **kwargs)

    # rpc GetMibDeviceData(common.ID) returns(omci.MibDeviceData) {...};
    @keyword
    @is_connected
    def voltha_service_get_mib_device_data(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetMibDeviceData, common_pb2.ID, param_dict, **kwargs)

    # rpc GetAlarmDeviceData(common.ID) returns(omci.AlarmDeviceData) {...};
    @keyword
    @is_connected
    def voltha_service_get_alarm_device_data(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetAlarmDeviceData, common_pb2.ID, param_dict, **kwargs)

    # rpc SimulateAlarm(SimulateAlarmRequest) returns(common.OperationResp) {...};
    @keyword
    @is_connected
    def voltha_service_simulate_alarm(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SimulateAlarm, voltha_pb2.SimulateAlarmRequest, param_dict, **kwargs)

    # rpc Subscribe (OfAgentSubscriber) returns (OfAgentSubscriber) {...};
    @keyword
    @is_connected
    def voltha_service_subscribe(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.Subscribe, voltha_pb2.OfAgentSubscriber, param_dict, **kwargs)

    # rpc EnablePort(voltha.Port) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_enable_port(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.EnablePort, voltha_pb2.Port, param_dict, **kwargs)

    # rpc DisablePort(voltha.Port) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_disable_port(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DisablePort, voltha_pb2.Port, param_dict, **kwargs)

    # rpc GetExtValue(common.ValueSpecifier) returns(common.ReturnValues) {...};
    @keyword
    @is_connected
    def voltha_service_get_ext_value(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetExtValue, common_pb2.ValueSpecifier, param_dict, **kwargs)

    # rpc SetExtValue(ValueSet) returns(google.protobuf.Empty) {...};
    @keyword
    @is_connected
    def voltha_service_set_ext_value(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SetExtValue, voltha_pb2.ValueSet, param_dict, **kwargs)

    # rpc StartOmciTestAction(OmciTestRequest) returns(TestResponse) {...};
    @keyword
    @is_connected
    def voltha_service_start_omci_test_action(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.StartOmciTestAction, voltha_pb2.OmciTestRequest, param_dict, **kwargs)
