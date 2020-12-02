from robot.api.deco import keyword
from grpc_robot.services.service import is_connected

from grpc_robot.services.service import Service
from dmi import sw_management_service_pb2_grpc, sw_management_service_pb2, hw_pb2


class NativeSoftwareManagementService(Service):

    prefix = 'sw_management_service_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx, stub=sw_management_service_pb2_grpc.NativeSoftwareManagementServiceStub)

    # rpc GetSoftwareVersion(HardwareID) returns(GetSoftwareVersionInformationResponse);
    @keyword
    @is_connected
    def sw_management_service_get_software_version(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetSoftwareVersion, hw_pb2.HardwareID, param_dict, **kwargs)

    # rpc DownloadImage(DownloadImageRequest) returns(stream ImageStatus);
    @keyword
    @is_connected
    def sw_management_service_download_image(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.DownloadImage, sw_management_service_pb2.DownloadImageRequest, param_dict, **kwargs)

    # rpc ActivateImage(HardwareID) returns(stream ImageStatus);
    @keyword
    @is_connected
    def sw_management_service_activate_image(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ActivateImage, hw_pb2.HardwareID, param_dict, **kwargs)

    # rpc RevertToStandbyImage(HardwareID) returns(stream ImageStatus);
    @keyword
    @is_connected
    def sw_management_service_revert_to_standby_image(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.RevertToStandbyImage, hw_pb2.HardwareID, param_dict, **kwargs)

    # rpc UpdateStartupConfiguration(ConfigRequest) returns(stream ConfigResponse);
    @keyword
    @is_connected
    def sw_management_service_update_startup_configuration(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateStartupConfiguration, sw_management_service_pb2.ConfigRequest, param_dict, **kwargs)
