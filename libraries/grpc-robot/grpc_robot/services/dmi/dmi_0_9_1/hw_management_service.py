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
from robot.api.deco import keyword
from grpc_robot.services.service import is_connected

from grpc_robot.services.service import Service
from dmi import hw_management_service_pb2_grpc, hw_management_service_pb2, hw_pb2


class NativeHWManagementService(Service):

    prefix = 'hw_management_service_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=hw_management_service_pb2_grpc.NativeHWManagementServiceStub)

    @keyword
    @is_connected
    def hw_management_service_start_managing_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.StartManagingDevice, hw_pb2.ModifiableComponent, param_dict, **kwargs)

    @keyword
    @is_connected
    def hw_management_service_stop_managing_device(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.StopManagingDevice, hw_management_service_pb2.StopManagingDeviceRequest, param_dict, **kwargs)

    @keyword
    @is_connected
    def hw_management_service_get_physical_inventory(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetPhysicalInventory, hw_management_service_pb2.PhysicalInventoryRequest, param_dict, **kwargs)

    @keyword
    @is_connected
    def hw_management_service_get_hw_component_info(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetHWComponentInfo, hw_management_service_pb2.HWComponentInfoGetRequest, param_dict, **kwargs)

    @keyword
    @is_connected
    def hw_management_service_set_hw_component_info(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SetHWComponentInfo, hw_management_service_pb2.HWComponentInfoSetRequest, param_dict, **kwargs)

    # rpc GetManagedDevices(google.protobuf.Empty) returns(ManagedDevicesResponse);
    @keyword
    @is_connected
    def hw_management_service_get_managed_devices(self, **kwargs):
        return self._grpc_helper(self.stub.GetManagedDevices, hw_management_service_pb2.ManagedDevicesResponse, **kwargs)

    # rpc SetLoggingEndpoint(SetLoggingEndpointRequest) returns(SetRemoteEndpointResponse);
    @keyword
    @is_connected
    def hw_management_service_set_logging_endpoint(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SetLoggingEndpoint, hw_management_service_pb2.SetLoggingEndpointRequest, param_dict, **kwargs)

    # rpc GetLoggingEndpoint(Uuid) returns(GetLoggingEndpointResponse);
    @keyword
    @is_connected
    def hw_management_service_get_logging_endpoint(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetLoggingEndpoint, hw_pb2.Uuid, param_dict, **kwargs)

    # rpc SetMsgBusEndpoint(SetMsgBusEndpointRequest) returns(SetRemoteEndpointResponse);
    @keyword
    @is_connected
    def hw_management_service_set_msg_bus_endpoint(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SetMsgBusEndpoint, hw_management_service_pb2.SetMsgBusEndpointRequest, param_dict, **kwargs)

    # rpc GetMsgBusEndpoint(google.protobuf.Empty) returns(GetMsgBusEndpointResponse);
    @keyword
    @is_connected
    def hw_management_service_get_msg_bus_endpoint(self, **kwargs):
        return self._grpc_helper(self.stub.GetMsgBusEndpoint, hw_management_service_pb2.GetMsgBusEndpointResponse, **kwargs)
