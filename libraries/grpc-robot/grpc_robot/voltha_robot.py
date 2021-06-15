# Copyright 2021 ADTRAN, Inc.
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
import voltha_protos

from robot.api.deco import keyword
from grpc_robot.grpc_robot import GrpcRobot


class GrpcVolthaRobot(GrpcRobot):
    """
    This library is intended to supported different Protocol Buffer definitions. Precondition is that python files
    generated from Protocol Buffer files are available in a pip package which must be installed before the library
    is used.

    | Supported device  | Pip package   | Pip package version | Library Name      |
    | voltha            | voltha-protos | 4.0.13              | grpc_robot.Voltha |
    """

    device = 'voltha'
    package_name = 'voltha-protos'
    installed_package = voltha_protos

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @keyword
    def voltha_version_get(self):
        """
        Retrieve the version of the currently used python module _voltha-protos_.

        *Return*: version string consisting of three dot-separated numbers (x.y.z)
        """
        return self.pb_version
