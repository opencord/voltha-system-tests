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
from voltha_protos import openolt_pb2_grpc, openolt_pb2, tech_profile_pb2, ext_config_pb2


class Openolt(Service):

    prefix = 'open_olt_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=openolt_pb2_grpc.OpenoltStub)

    # rpc DisableOlt(Empty) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_disable_olt(self, **kwargs):
        return self._grpc_helper(self.stub.DisableOlt, **kwargs)

    # rpc ReenableOlt(Empty) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_reenable_olt(self, **kwargs):
        return self._grpc_helper(self.stub.ReenableOlt, **kwargs)

    # rpc ActivateOnu(Onu) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_activate_onu(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ActivateOnu, openolt_pb2.Onu, param_dict, **kwargs)

    # rpc DeactivateOnu(Onu) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_deactivate_onu(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DeactivateOnu, openolt_pb2.Onu, param_dict, **kwargs)

    # rpc DeleteOnu(Onu) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_delete_onu(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DeleteOnu, openolt_pb2.Onu, param_dict, **kwargs)

    # rpc OmciMsgOut(OmciMsg) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_omci_msg_out(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.OmciMsgOut, openolt_pb2.OmciMsg, param_dict, **kwargs)

    # rpc OnuPacketOut(OnuPacket) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_onu_packet_out(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.OnuPacketOut, openolt_pb2.OnuPacket, param_dict, **kwargs)

    # rpc UplinkPacketOut(UplinkPacket) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_uplink_packet_out(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UplinkPacketOut, openolt_pb2.UplinkPacket, param_dict, **kwargs)

    # rpc FlowAdd(Flow) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_flow_add(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.FlowAdd, openolt_pb2.Flow, param_dict, **kwargs)

    # rpc FlowRemove(Flow) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_flow_remove(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.FlowRemove, openolt_pb2.Flow, param_dict, **kwargs)

    # rpc HeartbeatCheck(Empty) returns (Heartbeat) {...};
    @keyword
    @is_connected
    def open_olt_heartbeat_check(self, **kwargs):
        return self._grpc_helper(self.stub.HeartbeatCheck, **kwargs)

    # rpc EnablePonIf(Interface) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_enable_pon_if(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.EnablePonIf, openolt_pb2.Interface, param_dict, **kwargs)

    # rpc DisablePonIf(Interface) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_disable_pon_if(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DisablePonIf, openolt_pb2.Interface, param_dict, **kwargs)

    # rpc GetDeviceInfo(Empty) returns (DeviceInfo) {...};
    @keyword
    @is_connected
    def open_olt_get_device_info(self, **kwargs):
        return self._grpc_helper(self.stub.GetDeviceInfo, **kwargs)

    # rpc Reboot(Empty) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_reboot(self, **kwargs):
        return self._grpc_helper(self.stub.Reboot, **kwargs)

    # rpc CollectStatistics(Empty) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_collect_statistics(self, **kwargs):
        return self._grpc_helper(self.stub.CollectStatistics, **kwargs)

    # rpc GetOnuStatistics(Onu) returns (OnuStatistics) {...};
    @keyword
    @is_connected
    def open_olt_get_onu_statistics(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetOnuStatistics, openolt_pb2.Onu, param_dict, **kwargs)

    # rpc GetGemPortStatistics(OnuPacket) returns (GemPortStatistics) {...};
    @keyword
    @is_connected
    def open_olt_get_gem_port_statistics(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetGemPortStatistics, openolt_pb2.OnuPacket, param_dict, **kwargs)

    # rpc CreateTrafficSchedulers(tech_profile.TrafficSchedulers) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_create_traffic_schedulers(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.CreateTrafficSchedulers, tech_profile_pb2.TrafficSchedulers, param_dict, **kwargs)

    # rpc RemoveTrafficSchedulers(tech_profile.TrafficSchedulers) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_remove_traffic_schedulers(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.RemoveTrafficSchedulers, tech_profile_pb2.TrafficSchedulers, param_dict, **kwargs)

    # rpc CreateTrafficQueues(tech_profile.TrafficQueues) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_create_traffic_queues(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.CreateTrafficQueues, tech_profile_pb2.TrafficQueues, param_dict, **kwargs)

    # rpc RemoveTrafficQueues(tech_profile.TrafficQueues) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_remove_traffic_queues(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.RemoveTrafficQueues, tech_profile_pb2.TrafficQueues, param_dict, **kwargs)

    # rpc EnableIndication(Empty) returns (stream Indication) {...};
    @keyword
    @is_connected
    def open_olt_enable_indication(self, **kwargs):
        return self._grpc_helper(self.stub.EnableIndication, **kwargs)

    # rpc PerformGroupOperation(Group) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_perform_group_operation(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.PerformGroupOperation, openolt_pb2.Group, param_dict, **kwargs)

    # rpc DeleteGroup(Group) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_delete_group(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DeleteGroup, openolt_pb2.Group, param_dict, **kwargs)

    # rpc GetExtValue(ValueParam) returns (common.ReturnValues) {...};
    @keyword
    @is_connected
    def open_olt_get_ext_value(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetExtValue, openolt_pb2.ValueParam, param_dict, **kwargs)

    # rpc OnuItuPonAlarmSet(config.OnuItuPonAlarm) returns (Empty) {...};
    @keyword
    @is_connected
    def open_olt_onu_itu_pon_alarm_set(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.OnuItuPonAlarmSet, ext_config_pb2.OnuItuPonAlarm, param_dict, **kwargs)

    # rpc GetLogicalOnuDistanceZero(Onu) returns (OnuLogicalDistance) {...};
    @keyword
    @is_connected
    def open_olt_get_logical_onu_distance_zero(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetLogicalOnuDistanceZero, openolt_pb2.Onu, param_dict, **kwargs)

    # rpc GetLogicalOnuDistance(Onu) returns (OnuLogicalDistance) {...};
    @keyword
    @is_connected
    def open_olt_get_logical_onu_distance(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetLogicalOnuDistanceF, openolt_pb2.Onu, param_dict, **kwargs)
