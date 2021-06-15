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
from voltha_protos import ponsim_pb2_grpc, ponsim_pb2


class PonSim(Service):

    prefix = 'pon_sim_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=ponsim_pb2_grpc.PonSimStub)

    # rpc SendFrame(PonSimFrame) returns (google.protobuf.Empty) {}
    @keyword
    @is_connected
    def pon_sim_send_frame(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SendFrame, ponsim_pb2.PonSimFrame, param_dict, **kwargs)

    # rpc ReceiveFrames(google.protobuf.Empty) returns (stream PonSimFrame) {}
    @keyword
    @is_connected
    def pon_sim_receive_frames(self, **kwargs):
        return self._grpc_helper(self.stub.ReceiveFrames, **kwargs)

    # rpc GetDeviceInfo(google.protobuf.Empty) returns(PonSimDeviceInfo) {}
    @keyword
    @is_connected
    def pon_sim_get_device_info(self, **kwargs):
        return self._grpc_helper(self.stub.GetDeviceInfo, **kwargs)

    # rpc UpdateFlowTable(FlowTable) returns(google.protobuf.Empty) {}
    @keyword
    @is_connected
    def pon_sim_update_flow_table(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateFlowTable, ponsim_pb2.FlowTable, param_dict, **kwargs)

    # rpc GetStats(google.protobuf.Empty) returns(PonSimMetrics) {}
    @keyword
    @is_connected
    def pon_sim_get_stats(self, **kwargs):
        return self._grpc_helper(self.stub.GetStats, **kwargs)
