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
from dmi import hw_events_mgmt_service_pb2_grpc, hw_events_mgmt_service_pb2, hw_pb2


class NativeEventsManagementService(Service):

    prefix = 'hw_event_mgmt_service_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=hw_events_mgmt_service_pb2_grpc.NativeEventsManagementServiceStub)

    # rpc ListEvents(HardwareID) returns(ListEventsResponse);
    @keyword
    @is_connected
    def hw_event_mgmt_service_list_events(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListEvents, hw_pb2.HardwareID, param_dict, **kwargs)

    # rpc UpdateEventsConfiguration(EventsConfigurationRequest) returns(EventsConfigurationResponse);
    @keyword
    @is_connected
    def hw_event_mgmt_service_update_events_configuration(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateEventsConfiguration, hw_events_mgmt_service_pb2.EventsConfigurationRequest, param_dict, **kwargs)
