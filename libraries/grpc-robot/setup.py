# Copyright 2020 ADTRAN, Inc.
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
import os
from setuptools import setup, find_packages

NAME = 'grpc_robot'
with open('VERSION') as ff:
    VERSION = ff.read().strip()
with open('VERSION') as ff:
    README = ff.read()
with open('VERSION') as ff:
    LICENSE = ff.read()


def package_data():
    paths = []
    for (path, directories, filenames) in os.walk(NAME):
        for filename in filenames:
            if os.path.splitext(filename)[-1] == '.json':
                paths.append(os.path.join('..', path, filename))
    return paths


setup(
    name=NAME,
    version=VERSION,
    description='Package for sending/recieving messages to/from a gRPC server.',
    long_description=README,
    long_description_content_type="text/markdown",
    license=LICENSE,
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: OS Independent",
    ],
    install_requires=[
        'six',
        'robotframework>=3.1.2',
        'grpcio',
        'decorator',
        'attrs',
        'parsy',
        'device-management-interface>=0.9.1',
        'voltha-protos>=4.0.13'
    ],
    python_requires='>=3.6',
    packages=find_packages(exclude='tests'),
    package_data={
        NAME: package_data(),
    },
    data_files=[("", ["LICENSE"])],
    entry_points={
        'console_scripts': ['grpc_robot.protop = grpc_robot.tools.protop:main'],
    }
)
