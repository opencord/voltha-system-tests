import dmi

from robot.api.deco import keyword
from grpc_robot.grpc_robot import GrpcRobot


class GrpcDmiRobot(GrpcRobot):
    """
    This library is intended to supported different Protocol Buffer definitions. Precondition is that python files
    generated from Protocol Buffer files are available in a pip package which must be installed before the library
    is used.

    | Supported device  | Pip package                 | Pip package version | Library Name   |
    | dmi               | device-management-interface | 0.9.1               | grpc_robot.Dmi |
    | dmi               | device-management-interface | 0.9.2               | grpc_robot.Dmi |
    | dmi               | device-management-interface | 0.9.3               | grpc_robot.Dmi |
    | dmi               | device-management-interface | 0.9.4               | grpc_robot.Dmi |
    | dmi               | device-management-interface | 0.9.5               | grpc_robot.Dmi |
    """

    device = 'dmi'
    package_name = 'device-management-interface'
    installed_package = dmi

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @keyword
    def dmi_version_get(self):
        """
        Retrieve the version of the currently used python module _device-management-interface_.

        *Return*: version string consisting of three dot-separated numbers (x.y.z)
        """
        return self.pb_version
