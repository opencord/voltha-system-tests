# Robot gRPC package

This package allows to send/receive messages in a gRPC event stream.

## Supported devices
This gRPC ROBOT library is intended to supported different Protocol Buffer definitions. Precondition is that python files
generated from Protocol Buffer files are available in a pip package which must be installed before the library
is used.

| Supported device  | Pip package                 | Pip package version | Library Name   |
| ----------------- | --------------------------- | ------------------- | -------------- |
| dmi               | device-management-interface | 0.9.1               | [grpc_robot.Dmi](docs/dmi_0_9_1.html) |
|                   |                             | 0.9.2               | [grpc_robot.Dmi](docs/dmi_0_9_2.html) |
|                   |                             | 0.9.3               | [grpc_robot.Dmi](docs/dmi_0_9_3.html) |
|                   |                             | 0.9.4               | [grpc_robot.Dmi](docs/dmi_0_9_4.html) |
|                   |                             | 0.9.5               | [grpc_robot.Dmi](docs/dmi_0_9_5.html) |

## Tools
The package also offers some keywords for convenience to work with Robot Framework.

List of keywords: 
 - [grpc_robot.Collections](docs/collections.html)
 - [grpc_robot.DmiTools](docs/dmi_tools.html)

The list of keywords may be extended by request.

## Installation

    pip install robot-grpc

## How to use _robot-grpc_ in Robot Framework
The library has an named parameter _version_ to indicate the ProtoBuf file set to be used.

    Import Library    grpc_robot.Dmi
    Import Library    grpc_robot.Collections
    Import Library    grpc_robot.DmiTools
    
