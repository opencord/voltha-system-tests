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
from voltha_protos import health_pb2_grpc


class HealthService(Service):

    prefix = 'health_service_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=health_pb2_grpc.HealthServiceStub)

    # rpc GetHealthStatus(google.protobuf.Empty) returns (HealthStatus) {...};
    @keyword
    @is_connected
    def hw_management_service_get_health_status(self, **kwargs):
        return self._grpc_helper(self.stub.GetHealthStatus, **kwargs)
