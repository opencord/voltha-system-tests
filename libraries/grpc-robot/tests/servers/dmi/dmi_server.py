from concurrent import futures
import grpc

import dmi.hw_events_mgmt_service_pb2
import dmi.hw_events_mgmt_service_pb2_grpc
import dmi.hw_management_service_pb2
import dmi.hw_management_service_pb2_grpc
import dmi.hw_metrics_mgmt_service_pb2
import dmi.hw_metrics_mgmt_service_pb2_grpc
import dmi.sw_management_service_pb2
import dmi.sw_management_service_pb2_grpc
import dmi.commons_pb2
import dmi.sw_image_pb2


class DmiEventsManagementServiceServicer(dmi.hw_events_mgmt_service_pb2_grpc.NativeEventsManagementServiceServicer):

    def ListEvents(self, request, context):
        return dmi.hw_events_mgmt_service_pb2.ListEventsResponse(status=dmi.commons_pb2.OK_STATUS)

    def UpdateEventsConfiguration(self, request, context):
        return dmi.hw_events_mgmt_service_pb2.EventsConfigurationResponse(status=dmi.commons_pb2.OK_STATUS)


class DmiHwManagementServiceServicer(dmi.hw_management_service_pb2_grpc.NativeHWManagementServiceServicer):

    def StartManagingDevice(self, request, context):
        for _ in range(0, 1):
            yield dmi.hw_management_service_pb2.StartManagingDeviceResponse(status=dmi.commons_pb2.OK_STATUS)

    def StopManagingDevice(self, request, context):
        return dmi.hw_management_service_pb2.StopManagingDeviceResponse(status=dmi.commons_pb2.OK_STATUS)

    def GetManagedDevices(self, request, context):
        return dmi.hw_management_service_pb2.ManagedDevicesResponse()

    def GetPhysicalInventory(self, request, context):
        for _ in range(0, 1):
            yield dmi.hw_management_service_pb2.PhysicalInventoryResponse(status=dmi.commons_pb2.OK_STATUS)

    def GetHWComponentInfo(self, request, context):
        for _ in range(0, 1):
            yield dmi.hw_management_service_pb2.HWComponentInfoGetResponse(status=dmi.commons_pb2.OK_STATUS)

    def SetHWComponentInfo(self, request, context):
        return dmi.hw_management_service_pb2.HWComponentInfoSetResponse(status=dmi.commons_pb2.OK_STATUS)

    def SetLoggingEndpoint(self, request, context):
        return dmi.hw_management_service_pb2.SetRemoteEndpointResponse(status=dmi.commons_pb2.OK_STATUS)

    def GetLoggingEndpoint(self, request, context):
        return dmi.hw_management_service_pb2.GetLoggingEndpointResponse(status=dmi.commons_pb2.OK_STATUS)

    def SetMsgBusEndpoint(self, request, context):
        return dmi.hw_management_service_pb2.SetRemoteEndpointResponse(status=dmi.commons_pb2.OK_STATUS)

    def GetMsgBusEndpoint(self, request, context):
        return dmi.hw_management_service_pb2.GetMsgBusEndpointResponse(status=dmi.commons_pb2.OK_STATUS)

    def GetLoggableEntities(self, request, context):
        return dmi.hw_management_service_pb2.GetLogLevelResponse(status=dmi.commons_pb2.OK_STATUS)

    def SetLogLevel(self, request, context):
        return dmi.hw_management_service_pb2.SetLogLevelResponse()

    def GetLogLevel(self, request, context):
        return dmi.hw_management_service_pb2.GetLogLevelResponse(status=dmi.commons_pb2.OK_STATUS)


class DmiMetricsManagementServiceServicer(dmi.hw_metrics_mgmt_service_pb2_grpc.NativeMetricsManagementServiceServicer):

    def ListMetrics(self, request, context):
        return dmi.hw_metrics_mgmt_service_pb2.ListMetricsResponse(status=dmi.commons_pb2.OK_STATUS)

    def UpdateMetricsConfiguration(self, request, context):
        return dmi.hw_metrics_mgmt_service_pb2.MetricsConfigurationResponse(status=dmi.commons_pb2.OK_STATUS)

    def GetMetric(self, request, context):
        return dmi.hw_metrics_mgmt_service_pb2.GetMetricResponse(status=dmi.commons_pb2.OK_STATUS)


class DmiSoftwareManagementServiceServicer(dmi.sw_management_service_pb2_grpc.NativeSoftwareManagementServiceServicer):

    def GetSoftwareVersion(self, request, context):
        return dmi.sw_management_service_pb2.GetSoftwareVersionInformationResponse(status=dmi.commons_pb2.OK_STATUS)

    def DownloadImage(self, request, context):
        for _ in range(0, 1):
            yield dmi.sw_image_pb2.ImageStatus(status=dmi.commons_pb2.OK_STATUS)

    def ActivateImage(self, request, context):
        for _ in range(0, 1):
            yield dmi.sw_image_pb2.ImageStatus(status=dmi.commons_pb2.OK_STATUS)

    def RevertToStandbyImage(self, request, context):
        for _ in range(0, 1):
            yield dmi.sw_image_pb2.ImageStatus(status=dmi.commons_pb2.OK_STATUS)

    def UpdateStartupConfiguration(self, request, context):
        for _ in range(0, 1):
            yield dmi.sw_management_service_pb2.ConfigResponse(status=dmi.commons_pb2.OK_STATUS)


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

    dmi.hw_events_mgmt_service_pb2_grpc.add_NativeEventsManagementServiceServicer_to_server(DmiEventsManagementServiceServicer(), server)
    dmi.hw_management_service_pb2_grpc.add_NativeHWManagementServiceServicer_to_server(DmiHwManagementServiceServicer(), server)
    dmi.hw_metrics_mgmt_service_pb2_grpc.add_NativeMetricsManagementServiceServicer_to_server(DmiMetricsManagementServiceServicer(), server)
    dmi.sw_management_service_pb2_grpc.add_NativeSoftwareManagementServiceServicer_to_server(DmiSoftwareManagementServiceServicer(), server)

    server.add_insecure_port('127.0.01:50051')
    server.start()
    server.wait_for_termination()


if __name__ == '__main__':
    serve()
