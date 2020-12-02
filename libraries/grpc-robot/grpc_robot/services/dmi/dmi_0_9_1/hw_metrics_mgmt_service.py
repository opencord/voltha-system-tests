from robot.api.deco import keyword
from grpc_robot.services.service import is_connected

from grpc_robot.services.service import Service
from dmi import hw_metrics_mgmt_service_pb2_grpc, hw_metrics_mgmt_service_pb2, hw_pb2


class NativeMetricsManagementService(Service):

    prefix = 'hw_metrics_mgmt_service_'

    def __init__(self, ctx):
        super().__init__(ctx=ctx,stub=hw_metrics_mgmt_service_pb2_grpc.NativeMetricsManagementServiceStub)

    @keyword
    @is_connected
    def hw_metrics_mgmt_service_list_metrics(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.ListMetrics, hw_pb2.HardwareID, param_dict, **kwargs)

    @keyword
    @is_connected
    def hw_metrics_mgmt_service_update_metrics_configuration(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.UpdateMetricsConfiguration, hw_metrics_mgmt_service_pb2.MetricsConfigurationRequest, param_dict, **kwargs)

    @keyword
    @is_connected
    def hw_metrics_mgmt_service_get_metric(self, param_dict, **kwargs):
        return self._grpc_helper(self.stub.GetMetric, hw_metrics_mgmt_service_pb2.GetMetricRequest, param_dict, **kwargs)
