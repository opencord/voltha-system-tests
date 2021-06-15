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
from voltha_protos import extensions_pb2_grpc, extensions_pb2


class Extension(Service):

    prefix = 'extension_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=extensions_pb2_grpc.ExtensionStub)

    # rpc GetExtValue(SingleGetValueRequest) returns (SingleGetValueResponse);
    @keyword
    @is_connected
    def extension_get_ext_value(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetExtValue, extensions_pb2.SingleGetValueRequest, param_dict, **kwargs)

    # rpc SetExtValue(SingleSetValueRequest) returns (SingleSetValueResponse);
    @keyword
    @is_connected
    def extension_set_ext_value(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.SetExtValue, extensions_pb2.SingleSetValueRequest, param_dict, **kwargs)



